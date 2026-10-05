import AppIntents
import MemoData
import XCTest
import Models
import SwiftData
@testable import MemoSystem
@testable import MemoData

@MainActor
final class MemoEntityTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: StoredMemo.self, StoredResource.self, User.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func insertMemo(in context: ModelContext, account: String = "local", content: String = "A thought #ideas") throws -> StoredMemo {
        context.insert(User(accountKey: account, nickname: account))
        let memo = StoredMemo(accountKey: account, content: content, pinned: false, rowStatus: .normal,
                              visibility: .private, createdAt: .now, updatedAt: .now, syncState: .pendingCreate)
        context.insert(memo)
        try context.save()
        return memo
    }

    private func identifier(_ memo: StoredMemo) throws -> String {
        try XCTUnwrap(MemoEntityIdentifier(accountKey: memo.accountKey, persistentID: memo.id).token)
    }

    func testIdentitySurvivesServerAssignmentAndFreshContext() throws {
        let context = try makeContext()
        let memo = try insertMemo(in: context)
        let id = try identifier(memo)
        memo.serverId = "memos/server-assigned"
        memo.syncState = .synced
        try context.save()
        let store = MemoEntityStore(context: ModelContext(context.container), accountAvailable: { _ in true })
        let entity = try XCTUnwrap(store.entities(for: [id]).first)
        XCTAssertEqual(entity.id, id)
        XCTAssertEqual(entity.content, memo.content)
        XCTAssertEqual(entity.tags, ["ideas"])
        XCTAssertEqual(MemoEntityIdentifier(token: id)?.token, id)
    }

    func testRejectsAccountSpoofingUnavailableAccountsAndMalformedTokens() throws {
        let context = try makeContext()
        let memo = try insertMemo(in: context)
        context.insert(User(accountKey: "other", nickname: "Other"))
        try context.save()
        let spoof = try XCTUnwrap(MemoEntityIdentifier(accountKey: "other", persistentID: memo.id).token)
        let store = MemoEntityStore(context: context, accountAvailable: { _ in true })
        XCTAssertTrue(try store.entities(for: [spoof, "invalid"]).isEmpty)
        XCTAssertNil(try store.memo(for: spoof))
        let unavailable = MemoEntityStore(context: context, accountAvailable: { _ in false })
        XCTAssertTrue(try unavailable.entities(for: [identifier(memo)]).isEmpty)
        XCTAssertTrue(try unavailable.search("").isEmpty)
    }

    func testArchiveRestoreSoftDeleteAndHardDeleteResolution() throws {
        let context = try makeContext()
        let memo = try insertMemo(in: context)
        let id = try identifier(memo)
        let legacy = try XCTUnwrap(PersistentIdentifierTokenCoder.encode(memo.id))
        let store = MemoEntityStore(context: context, accountAvailable: { _ in true })
        XCTAssertEqual(try store.entity(forLegacyIdentifier: legacy)?.id, id)
        memo.rowStatus = .archived
        try context.save()
        XCTAssertTrue(try store.entities(for: [id]).isEmpty)
        XCTAssertNil(try store.entity(forLegacyIdentifier: legacy))
        memo.rowStatus = .normal
        try context.save()
        XCTAssertEqual(try store.entities(for: [id]).count, 1)
        memo.softDeleted = true
        try context.save()
        XCTAssertNil(try store.memo(for: id))
        context.delete(memo)
        try context.save()
        let freshStore = MemoEntityStore(context: ModelContext(context.container), accountAvailable: { _ in true })
        XCTAssertNil(try freshStore.memo(for: id))
        XCTAssertTrue(try freshStore.entities(for: [id]).isEmpty)
    }

    func testSearchAcrossAccountsAndRemovedUser() throws {
        let context = try makeContext()
        let first = try insertMemo(in: context, account: "a", content: "Coffee #ideas")
        let second = try insertMemo(in: context, account: "b", content: "COFFEE tomorrow")
        let store = MemoEntityStore(context: context, accountAvailable: { _ in true })
        XCTAssertEqual(Set(try store.search("coffee").map(\.id)), Set(try [identifier(first), identifier(second)]))
        XCTAssertEqual(try store.search("#ideas").map(\.id), [try identifier(first)])
        XCTAssertEqual(try store.search("", limit: 1).count, 1)
        for user in try context.fetch(FetchDescriptor<User>()) where user.accountKey == "a" { context.delete(user) }
        try context.save()
        XCTAssertNil(try store.memo(for: identifier(first)))
        XCTAssertEqual(try store.search("coffee").map(\.id), [try identifier(second)])
    }

    func testAttachmentOnlyMemoHasNonemptyTitleAndAccountAwareURL() throws {
        let context = try makeContext()
        let memo = try insertMemo(in: context, content: "")
        let entity = try XCTUnwrap(MemoEntity(memo: memo, accountName: "Local"))
        XCTAssertFalse(entity.title.isEmpty)
        let components = try XCTUnwrap(URLComponents(url: entity.url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first?.value, entity.id)
        XCTAssertEqual(entity.attributeSet.relatedUniqueIdentifier, entity.id)
    }

    func testActionsUseOwningAccountAndPreserveMemoFields() async throws {
        let context = try makeContext()
        let memo = try insertMemo(in: context, account: "owner", content: "Original")
        memo.visibility = .public
        let resource = StoredResource(accountKey: "owner", filename: "note.txt", size: 1, mimeType: "text/plain",
                                      createdAt: .now, updatedAt: .now, urlString: "https://example.com/note.txt", memo: memo)
        context.insert(resource)
        try context.save()
        let id = try identifier(memo)
        let store = MemoEntityStore(context: context, accountAvailable: { _ in true })
        var resolvedAccounts: [String] = []
        let serviceForAccount: (String) -> (any Service)? = { key in
            resolvedAccounts.append(key)
            return LocalService(context: context, accountKey: key)
        }
        let appended = try await MemoActions.append("More", to: id, store: store, serviceForAccount: serviceForAccount)
        XCTAssertEqual(appended.content, "Original\nMore")
        let pinned = try await MemoActions.pin(id, pinned: true, store: store, serviceForAccount: serviceForAccount)
        XCTAssertTrue(pinned.isPinned)
        XCTAssertEqual(resolvedAccounts, ["owner", "owner"])
        XCTAssertEqual(memo.visibility, .public)
        XCTAssertEqual(memo.resources.map(\.filename), ["note.txt"])
        XCTAssertEqual(memo.content, "Original\nMore")
        do {
            _ = try await MemoActions.append(" \n", to: id, store: store, serviceForAccount: serviceForAccount)
            XCTFail("Empty append should fail")
        } catch MemoIntentError.emptyContent {}
        memo.softDeleted = true
        try context.save()
        do {
            _ = try await MemoActions.pin(id, pinned: false, store: store, serviceForAccount: serviceForAccount)
            XCTFail("Deleted memo should not be modified")
        } catch MemoIntentError.notFound {}
        XCTAssertEqual(resolvedAccounts.count, 2)
    }

    func testIndexResolvesQueuedChangesAtExecutionAndRemovesArchivedMemo() async throws {
        let context = try makeContext()
        let memo = try insertMemo(in: context)
        let id = try identifier(memo)
        let client = RecordingMemoIndex()
        let index = MemoSpotlightIndex(client: client, indexesInMemoryStores: true, accountAvailable: { _ in true })
        index.update(identifiers: [id], container: context.container)
        memo.content = "The latest text"
        try context.save()
        await index.flush()
        XCTAssertEqual(client.entities[id]?.content, "The latest text")
        memo.rowStatus = .archived
        try context.save()
        index.update(identifiers: [id], container: context.container)
        await index.flush()
        XCTAssertNil(client.entities[id])
        XCTAssertTrue(client.removed.contains(id))
    }

    func testRebuildRepairsMissedDeletionsAndIndexFailure() async throws {
        let context = try makeContext()
        let memo = try insertMemo(in: context)
        let id = try identifier(memo)
        let client = RecordingMemoIndex()
        let index = MemoSpotlightIndex(client: client, indexesInMemoryStores: true, accountAvailable: { _ in true })
        client.failNextWrite = true
        index.update(identifiers: [id], container: context.container)
        await index.flush()
        XCTAssertNil(client.entities[id])
        await index.rebuild(container: context.container)
        XCTAssertEqual(client.entities[id]?.content, memo.content)
        context.delete(memo)
        try context.save()
        await index.rebuild(container: context.container)
        XCTAssertTrue(client.entities.isEmpty)
    }

    func testDataChangesUpdateIndexThroughObserver() async throws {
        let context = try makeContext()
        context.insert(User(accountKey: "local", nickname: "Local"))
        try context.save()
        let client = RecordingMemoIndex()
        let index = MemoSpotlightIndex(client: client, indexesInMemoryStores: true, accountAvailable: { _ in true })
        let previous = MemoChanges.shared.observer
        index.startObserving()
        defer { MemoChanges.shared.observer = previous }
        let service = LocalService(context: context, accountKey: "local")
        let memo = try await service.createMemo(content: "Indexed", visibility: .private, resources: [], tags: nil)
        let id = try identifier(memo)
        await MemoChanges.shared.flush()
        XCTAssertEqual(client.entities[id]?.content, "Indexed")
        try await service.archiveMemo(id: memo.id)
        await MemoChanges.shared.flush()
        XCTAssertNil(client.entities[id])
        try await service.restoreMemo(id: memo.id)
        await MemoChanges.shared.flush()
        XCTAssertNotNil(client.entities[id])
        try await service.deleteMemo(id: memo.id)
        await MemoChanges.shared.flush()
        XCTAssertNil(client.entities[id])
    }

    func testOpenIntentUsesHostNavigationHandler() async throws {
        let context = try makeContext()
        let memo = try insertMemo(in: context)
        let entity = try XCTUnwrap(MemoEntity(memo: memo, accountName: "Local"))
        var opened: String?
        let navigator = MemoNavigator { opened = $0 }
        let intent = OpenMemoIntent(target: entity, navigator: navigator)
        _ = try await intent.perform()
        XCTAssertEqual(opened, entity.id)
        if #available(iOS 27, *) {
            opened = nil
            let siriIntent = SiriOpenMemoIntent(target: SiriMemoEntity(entity), navigator: navigator)
            _ = try await siriIntent.perform()
            XCTAssertEqual(opened, entity.id)
        }
    }
}

@MainActor
private final class RecordingMemoIndex: MemoSearchIndexClient {
    var entities: [String: MemoEntity] = [:]
    var removed: Set<String> = []
    var failNextWrite = false
    func index(_ entities: [MemoEntity]) async throws {
        if failNextWrite { failNextWrite = false; throw CocoaError(.fileWriteUnknown) }
        for entity in entities { self.entities[entity.id] = entity }
    }
    func remove(_ identifiers: [String]) async throws {
        removed.formUnion(identifiers)
        for id in identifiers { entities[id] = nil }
    }
    func removeAll() async throws { entities.removeAll() }
}
