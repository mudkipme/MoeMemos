import XCTest
import Models
import SwiftData
@testable import MemoData
@testable import MemoSystem

@MainActor
final class MemoSpotlightIndexTests: XCTestCase {
    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: User.self, StoredMemo.self, StoredResource.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func memo(in context: ModelContext, content: String = "Memo") throws -> StoredMemo {
        if try context.fetch(FetchDescriptor<User>()).isEmpty {
            context.insert(User(accountKey: "local", nickname: "Local"))
        }
        let memo = StoredMemo(accountKey: "local", content: content, pinned: false, rowStatus: .normal,
                              visibility: .private, createdAt: .now, updatedAt: .now)
        context.insert(memo)
        try context.save()
        return memo
    }

    private func token(_ memo: StoredMemo) throws -> String {
        try XCTUnwrap(MemoEntityIdentifier(accountKey: memo.accountKey, persistentID: memo.id).token)
    }

    private func journal() -> (MemoIndexJournal, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (MemoIndexJournal(directory: directory), directory)
    }

    func testFlushTimesOutWhileIndexingIsStillBlockedAndLeavesWorkForRecovery() async throws {
        let context = try context()
        let memo = try memo(in: context)
        let (journal, directory) = journal()
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = TestSearchIndex()
        client.blockWrites = true
        let index = MemoSpotlightIndex(client: client, indexesInMemoryStores: true, journal: journal)
        index.update(identifiers: [try token(memo)], container: context.container)

        let returned = expectation(description: "Flush returns without Spotlight completing")
        let wait = Task {
            await index.flush(timeout: .milliseconds(20))
            returned.fulfill()
        }
        await fulfillment(of: [returned], timeout: 1)
        XCTAssertTrue(client.entities.isEmpty)
        XCTAssertEqual(try journal.pending().count, 1)
        client.release()
        await wait.value
        await index.flush()
        XCTAssertEqual(client.entities[try token(memo)]?.content, "Memo")
        XCTAssertTrue(try journal.pending().isEmpty)
    }

    func testCancellingFlushDoesNotCancelQueuedIndexChanges() async throws {
        let context = try context()
        let memo = try memo(in: context)
        let client = TestSearchIndex()
        client.blockWrites = true
        let index = MemoSpotlightIndex(client: client, indexesInMemoryStores: true)
        index.update(identifiers: [try token(memo)], container: context.container)
        let returned = expectation(description: "Cancelled flush returns")
        let wait = Task {
            await index.flush(timeout: .seconds(30))
            returned.fulfill()
        }
        // Give the wait a chance to register before exercising cancellation.
        await Task.yield()
        wait.cancel()
        await fulfillment(of: [returned], timeout: 1)
        client.release()
        await index.flush()
        XCTAssertNotNil(client.entities[try token(memo)])
    }

    func testActivationDoesNotRewriteUnchangedMemosAcrossLaunches() async throws {
        let context = try context()
        _ = try memo(in: context)
        _ = try memo(in: context, content: "Other memo")
        let (journal, directory) = journal()
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = TestSearchIndex()
        let first = MemoSpotlightIndex(client: client, indexesInMemoryStores: true, journal: journal)
        await first.synchronize(container: context.container)
        XCTAssertEqual(client.indexed.count, 2)
        XCTAssertEqual(client.removeAllCount, 1)
        let nextLaunch = MemoSpotlightIndex(client: client, indexesInMemoryStores: true,
                                           journal: MemoIndexJournal(directory: directory))
        await nextLaunch.synchronize(container: context.container)
        await nextLaunch.synchronize(container: context.container)
        XCTAssertEqual(client.indexed.count, 2)
        XCTAssertEqual(client.removeAllCount, 1)
    }

    func testActivationReplaysOnlyChangedAndDeletedMemosFromAnotherProcess() async throws {
        let context = try context()
        let changed = try memo(in: context, content: "Before")
        let removed = try memo(in: context, content: "Delete me")
        _ = try memo(in: context, content: "Unchanged")
        let changedID = try token(changed)
        let removedID = try token(removed)
        let (journal, directory) = journal()
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = TestSearchIndex()
        let index = MemoSpotlightIndex(client: client, indexesInMemoryStores: true, journal: journal)
        await index.synchronize(container: context.container)
        client.indexed = []

        changed.content = "After"
        context.delete(removed)
        try context.save()
        let extensionJournal = MemoIndexJournal(directory: directory)
        _ = try extensionJournal.append(identifiers: [changedID, removedID])
        // Duplicate records are coalesced when replaying extension work.
        _ = try extensionJournal.append(identifiers: [changedID])
        await index.synchronize(container: context.container)

        XCTAssertEqual(client.indexed, [changedID])
        XCTAssertEqual(client.entities[changedID]?.content, "After")
        XCTAssertNil(client.entities[removedID])
        XCTAssertEqual(client.removed, [removedID])
        XCTAssertEqual(client.removeAllCount, 1)
        XCTAssertTrue(try journal.pending().isEmpty)
    }

    func testFailedWriteIsReplayedAfterRestart() async throws {
        let context = try context()
        let memo = try memo(in: context)
        let id = try token(memo)
        let (journal, directory) = journal()
        defer { try? FileManager.default.removeItem(at: directory) }
        try journal.markInitialized()
        let client = TestSearchIndex()
        client.failNextWrite = true
        let first = MemoSpotlightIndex(client: client, indexesInMemoryStores: true, journal: journal)
        first.update(identifiers: [id], container: context.container)
        await first.flush()
        XCTAssertNil(client.entities[id])
        XCTAssertEqual(try journal.pending().count, 1)
        let nextLaunch = MemoSpotlightIndex(client: client, indexesInMemoryStores: true,
                                           journal: MemoIndexJournal(directory: directory))
        await nextLaunch.synchronize(container: context.container)
        XCTAssertNotNil(client.entities[id])
        XCTAssertEqual(client.removeAllCount, 0)
        XCTAssertTrue(try journal.pending().isEmpty)
    }

    func testSuccessfulExtensionWriteRemainsQueuedUntilAppReplaysIt() async throws {
        let context = try context()
        let memo = try memo(in: context)
        let id = try token(memo)
        let (journal, directory) = journal()
        defer { try? FileManager.default.removeItem(at: directory) }
        try journal.markInitialized()
        let client = TestSearchIndex()
        let extensionIndex = MemoSpotlightIndex(client: client, indexesInMemoryStores: true,
                                                journal: journal, retainsChangesForApp: true)
        extensionIndex.update(identifiers: [id], container: context.container)
        await extensionIndex.flush()
        XCTAssertNotNil(client.entities[id])
        XCTAssertEqual(try journal.pending().count, 1)
        let appIndex = MemoSpotlightIndex(client: client, indexesInMemoryStores: true,
                                          journal: MemoIndexJournal(directory: directory))
        await appIndex.synchronize(container: context.container)
        XCTAssertTrue(try journal.pending().isEmpty)
        XCTAssertEqual(client.removeAllCount, 0)
    }

    func testAccountRenameUpdatesMemoMetadataWithoutRebuilding() async throws {
        let context = try context()
        let memo = try memo(in: context)
        let id = try token(memo)
        let client = TestSearchIndex()
        let index = MemoSpotlightIndex(client: client, indexesInMemoryStores: true)
        let previous = MemoChanges.shared.observer
        index.startObserving()
        defer { MemoChanges.shared.observer = previous }
        let store = LocalStore(context: context, accountKey: "local")
        store.upsertUser(UserSnapshot(accountKey: "local", nickname: "Renamed"))
        try store.save()
        await index.flush()
        XCTAssertEqual(client.entities[id]?.accountName, "Renamed")
        XCTAssertEqual(client.indexed, [id])
        store.upsertUser(UserSnapshot(accountKey: "local", nickname: "Renamed"))
        try store.save()
        await index.flush()
        XCTAssertEqual(client.indexed, [id])
        XCTAssertEqual(client.removeAllCount, 0)
    }

    func testExplicitRepairStillRebuildsAndKeepsNewlyQueuedWork() async throws {
        let context = try context()
        let memo = try memo(in: context)
        let id = try token(memo)
        let (journal, directory) = journal()
        defer { try? FileManager.default.removeItem(at: directory) }
        try journal.markInitialized()
        _ = try journal.append(identifiers: nil)
        let client = TestSearchIndex()
        client.onIndex = {
            _ = try journal.append(identifiers: [id])
        }
        let index = MemoSpotlightIndex(client: client, indexesInMemoryStores: true, journal: journal)
        await index.synchronize(container: context.container)
        XCTAssertEqual(client.removeAllCount, 1)
        XCTAssertEqual(try journal.pending().count, 1)
        XCTAssertEqual(try journal.pending().first?.identifiers, [id])
    }
}

@MainActor
private final class TestSearchIndex: MemoSearchIndexClient {
    var entities: [String: MemoEntity] = [:]
    var indexed: [String] = []
    var removed: Set<String> = []
    var removeAllCount = 0
    var failNextWrite = false
    var blockWrites = false
    var onIndex: (() throws -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?

    func index(_ entities: [MemoEntity]) async throws {
        if blockWrites {
            await withCheckedContinuation { continuation = $0 }
        }
        if failNextWrite {
            failNextWrite = false
            throw CocoaError(.fileWriteUnknown)
        }
        for entity in entities { self.entities[entity.id] = entity }
        indexed += entities.map(\.id)
        try onIndex?()
    }

    func remove(_ identifiers: [String]) async throws {
        removed.formUnion(identifiers)
        for id in identifiers { entities[id] = nil }
    }

    func removeAll() async throws {
        removeAllCount += 1
        entities.removeAll()
    }

    func release() {
        blockWrites = false
        continuation?.resume()
        continuation = nil
    }
}
