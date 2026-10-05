import XCTest
import Models
import SwiftData
@testable import MemoData

@MainActor
final class MemoChangesTests: XCTestCase {
    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: User.self, StoredMemo.self, StoredResource.self,
                                         configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    func testSavedChangesContainPermanentIdentityAndCommittedState() async throws {
        let context = try context()
        let observer = RecordingChanges()
        let previous = MemoChanges.shared.observer
        MemoChanges.shared.observer = observer
        defer { MemoChanges.shared.observer = previous }
        let service = LocalService(context: context, accountKey: "local")
        let memo = try await service.createMemo(content: "First", visibility: .private, resources: [], tags: nil)
        XCTAssertEqual(observer.identifiers.first?.accountKey, "local")
        XCTAssertEqual(observer.committedContents, ["First"])
        let originalToken = observer.identifiers.first?.token
        _ = try await service.updateMemo(id: memo.id, content: "Updated", resources: nil, visibility: nil, tags: nil, pinned: nil)
        XCTAssertEqual(observer.committedContents.last, "Updated")
        XCTAssertEqual(observer.identifiers.last?.token, originalToken)
        await MemoChanges.shared.flush()
        XCTAssertEqual(observer.flushCount, 1)
        XCTAssertNil(observer.readError)
    }

    func testStorageWorksWithoutSystemIntegration() async throws {
        let context = try context()
        let previous = MemoChanges.shared.observer
        MemoChanges.shared.observer = nil
        defer { MemoChanges.shared.observer = previous }
        let service = LocalService(context: context, accountKey: "local")
        let memo = try await service.createMemo(content: "Offline", visibility: .private, resources: [], tags: nil)
        XCTAssertEqual(service.memo(id: memo.id)?.content, "Offline")
        await MemoChanges.shared.flush()
    }

    func testAccountSelectionRestoresServiceAndDefaultVisibility() throws {
        let context = try context()
        context.insert(User(accountKey: "local", nickname: "Local", defaultVisibility: .public))
        try context.save()
        let suite = "MemoDataTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let manager = AccountManager(modelContext: context, preferences: preferences)
        XCTAssertNil(manager.currentAccount)
        try manager.selectAccount(key: "local")
        XCTAssertEqual(manager.currentUser?.defaultVisibility, .public)
        XCTAssertNotNil(manager.currentService)
        let restored = AccountManager(modelContext: context, preferences: preferences)
        XCTAssertEqual(restored.currentAccount?.key, "local")
        XCTAssertNotNil(restored.currentService)
    }
}

@MainActor
private final class RecordingChanges: MemoChangeObserver {
    var identifiers: [MemoEntityIdentifier] = []
    var committedContents: [String] = []
    var readError: Error?
    var flushCount = 0

    func memosDidSave(identifiers: Set<MemoEntityIdentifier>, container: ModelContainer) {
        self.identifiers.append(contentsOf: identifiers)
        do {
            // A separate context must see the saved changes before observers run.
            committedContents += try ModelContext(container).fetch(FetchDescriptor<StoredMemo>()).map(\.content)
        } catch { readError = error }
    }
    func flush() async { flushCount += 1 }
}
