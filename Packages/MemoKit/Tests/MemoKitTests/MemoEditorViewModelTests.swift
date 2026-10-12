import MemoData
import Models
import SwiftData
import XCTest
@testable import MemoKit

@MainActor
final class MemoEditorViewModelTests: XCTestCase {
    func testImportsStayInTheDraftAccountAndRejectAnotherAccount() async throws {
        let container = try ModelContainer(
            for: StoredMemo.self, StoredResource.self, User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let suite = "MemoEditorViewModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Account.local.key, forKey: "currentAccountKey")
        let manager = AccountManager(modelContext: container.mainContext, preferences: defaults)
        let editor = MemoEditorViewModel(accountManager: manager)
        editor.accountKey = "other-account"

        do {
            try await editor.upload(data: Data([1]), filename: "test.txt", mimeType: "text/plain")
            XCTFail("An editor must not import into another account")
        } catch {
            guard case MemoEditorError.accountChanged = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertTrue(editor.resourceList.isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<StoredResource>()).isEmpty)
    }
}
