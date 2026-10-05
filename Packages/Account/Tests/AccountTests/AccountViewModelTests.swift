import XCTest
import MemoData
import Models
import SwiftData
@testable import Account

@MainActor
final class AccountViewModelTests: XCTestCase {
    func testLogoutRefreshesUsersWithoutWaitingForIndexing() async throws {
        let container = try ModelContainer(
            for: User.self, StoredMemo.self, StoredResource.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let account = Account.memosV1(host: "https://\(UUID().uuidString).example.com", id: "1", accessToken: "test")
        context.insert(User(accountKey: account.key, nickname: "Remote"))
        context.insert(User(accountKey: Account.local.key, nickname: "Local"))
        context.insert(StoredMemo(
            accountKey: account.key, content: "Cached memo", pinned: false,
            rowStatus: .normal, visibility: .private, createdAt: .now, updatedAt: .now
        ))
        try context.save()

        let suite = "AccountViewModelTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let manager = AccountManager(modelContext: context, preferences: preferences)
        try manager.selectAccount(key: Account.local.key)
        let viewModel = AccountViewModel(currentContext: context, accountManager: manager)
        XCTAssertEqual(viewModel.users.count, 2)

        let observer = RecordingChanges()
        let previousObserver = MemoChanges.shared.observer
        MemoChanges.shared.observer = observer
        defer { MemoChanges.shared.observer = previousObserver }

        try await viewModel.logout(account: account)

        XCTAssertEqual(viewModel.users.map(\.accountKey), [Account.local.key])
        XCTAssertEqual(manager.currentAccount, .local)
        XCTAssertTrue(try context.fetch(FetchDescriptor<StoredMemo>()).isEmpty)
        // Index cleanup is still requested, but is not a prerequisite for logout.
        XCTAssertEqual(observer.identifiers.count, 1)
        XCTAssertEqual(observer.identifiers.first?.accountKey, account.key)
        XCTAssertEqual(observer.flushCount, 0)
    }
}

@MainActor
private final class RecordingChanges: MemoChangeObserver {
    var identifiers: Set<MemoEntityIdentifier> = []
    var flushCount = 0

    func memosDidSave(identifiers: Set<MemoEntityIdentifier>, container: ModelContainer) {
        self.identifiers.formUnion(identifiers)
    }

    func flush() async {
        flushCount += 1
    }
}
