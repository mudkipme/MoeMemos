import XCTest
import SwiftData
import Models
@testable import MemoKit

@MainActor
final class MemoDraftTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "MemoDraftTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: StoredMemo.self, StoredResource.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeResource() -> StoredResource {
        StoredResource(
            accountKey: "test", filename: "photo.jpg", size: 10, mimeType: "image/jpeg",
            createdAt: .now, updatedAt: .now, urlString: ""
        )
    }

    func testRestoresAttachmentOnlyDraftAndVisibility() throws {
        let container = try makeContainer()
        let resource = makeResource()
        container.mainContext.insert(resource)
        try container.mainContext.save()

        try withDefaults { defaults in
            let store = MemoDraftStore(defaults: defaults, accountKey: "test")
            let draft = MemoDraft(text: "", visibility: .public, resourceIDs: [resource.id])
            try store.save(draft)

            let restored = MemoDraftStore(defaults: defaults, accountKey: "test")
                .load(defaultVisibility: .private)
            XCTAssertEqual(restored, draft)
            let id = try XCTUnwrap(restored?.resourceIDs.first)
            XCTAssertEqual((container.mainContext.model(for: id) as? StoredResource)?.filename, "photo.jpg")
        }
    }

    func testLegacyTextDraftMigratesWithoutBeingResurrectedAfterSave() throws {
        try withDefaults { defaults in
            defaults.set("Existing draft", forKey: "draft.test")
            let store = MemoDraftStore(defaults: defaults, accountKey: "test")
            let migrated = try XCTUnwrap(store.load(defaultVisibility: .private))
            XCTAssertEqual(migrated.text, "Existing draft")
            XCTAssertEqual(migrated.visibility, .private)
            try store.save(migrated)
            XCTAssertNil(defaults.object(forKey: "draft.test"))
            store.clear()
            XCTAssertNil(store.load(defaultVisibility: .private))
        }
    }

    func testNewMemoAndEditDraftsAreIsolatedByAccountAndMemo() throws {
        let container = try makeContainer()
        let memo = StoredMemo(
            accountKey: "test", content: "Original", pinned: false, rowStatus: .normal,
            visibility: .private, createdAt: .now, updatedAt: .now
        )
        container.mainContext.insert(memo)
        try container.mainContext.save()

        try withDefaults { defaults in
            let newStore = MemoDraftStore(defaults: defaults, accountKey: "test")
            let editStore = MemoDraftStore(defaults: defaults, accountKey: "test", memoID: memo.id)
            let otherStore = MemoDraftStore(defaults: defaults, accountKey: "other")
            let newDraft = MemoDraft(text: "New", visibility: .private, resourceIDs: [])
            let editDraft = MemoDraft(text: "Edited", visibility: .public, resourceIDs: [])
            try newStore.save(newDraft)
            try editStore.save(editDraft)
            XCTAssertEqual(newStore.load(defaultVisibility: .private), newDraft)
            XCTAssertEqual(editStore.load(defaultVisibility: .private), editDraft)
            XCTAssertNil(otherStore.load(defaultVisibility: .private))
            editStore.clear()
            XCTAssertNil(editStore.load(defaultVisibility: .private))
            XCTAssertEqual(newStore.load(defaultVisibility: .private), newDraft)
            XCTAssertEqual(memo.content, "Original")
            XCTAssertTrue(MemoDraftStore.hasNewMemoDraft(defaults: defaults, accountKey: "test"))
            newStore.clear()
            try editStore.save(editDraft)
            XCTAssertFalse(MemoDraftStore.hasNewMemoDraft(defaults: defaults, accountKey: "test"))
        }
    }

    func testResumeDraftIgnoresWhitespaceAndClearedDrafts() throws {
        try withDefaults { defaults in
            let store = MemoDraftStore(defaults: defaults, accountKey: "test")
            defaults.set("Legacy draft", forKey: "draft.test")
            XCTAssertTrue(MemoDraftStore.hasNewMemoDraft(defaults: defaults, accountKey: "test"))
            try store.save(MemoDraft(text: " \n\t ", visibility: .private, resourceIDs: []))
            XCTAssertFalse(MemoDraftStore.hasNewMemoDraft(defaults: defaults, accountKey: "test"))
            try store.save(MemoDraft(text: "A thought", visibility: .private, resourceIDs: []))
            XCTAssertTrue(MemoDraftStore.hasNewMemoDraft(defaults: defaults, accountKey: "test"))
            XCTAssertFalse(MemoDraftStore.hasNewMemoDraft(defaults: defaults, accountKey: "other"))
            store.clear()
            XCTAssertFalse(MemoDraftStore.hasNewMemoDraft(defaults: defaults, accountKey: "test"))
        }
    }

    func testResumeDraftIncludesAttachmentOnlyDrafts() throws {
        let container = try makeContainer()
        let resource = makeResource()
        container.mainContext.insert(resource)
        try container.mainContext.save()

        try withDefaults { defaults in
            let store = MemoDraftStore(defaults: defaults, accountKey: "test")
            try store.save(MemoDraft(text: "", visibility: .private, resourceIDs: [resource.id]))
            XCTAssertTrue(MemoDraftStore.hasNewMemoDraft(defaults: defaults, accountKey: "test"))
        }
    }

    func testRemovingAttachmentOnlyChangesTheDraft() async throws {
        let container = try makeContainer()
        let resource = makeResource()
        let memo = StoredMemo(
            accountKey: "test", content: "Original", pinned: false, rowStatus: .normal,
            visibility: .private, createdAt: .now, updatedAt: .now, resources: [resource]
        )
        container.mainContext.insert(memo)
        try container.mainContext.save()
        let editor = MemoEditorViewModel()
        editor.resourceList = [resource]

        try await editor.deleteResource(id: resource.id)

        XCTAssertTrue(editor.resourceList.isEmpty)
        XCTAssertFalse(resource.softDeleted)
        XCTAssertEqual(resource.memo?.id, memo.id)
        XCTAssertEqual(memo.resources.map(\.id), [resource.id])
        // Reopening without saving still has the original attachment.
        let reopened = MemoEditorViewModel()
        reopened.resourceList = memo.resources
        XCTAssertEqual(reopened.resourceList.map(\.id), [resource.id])
    }
}
