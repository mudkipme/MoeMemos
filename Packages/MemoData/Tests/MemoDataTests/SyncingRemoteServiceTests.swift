import Foundation
import Models
import SwiftData
import XCTest
@testable import MemoData

@MainActor
final class SyncingRemoteServiceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: User.self, StoredMemo.self, StoredResource.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testOfflineEditThenOfflineDeleteDeletesOnServerWithoutResurrecting() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        let memo = try await service.createMemo(content: "Original", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.syncState, .synced)
        XCTAssertEqual(remote.memos.count, 1)

        // Go offline, edit memo, then delete it.
        remote.errorToThrow = URLError(.notConnectedToInternet)
        _ = try await service.updateMemo(id: memo.id, content: "Edited offline", resources: nil, visibility: nil, tags: nil, pinned: nil)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.syncState, .pendingUpdate)

        try await service.deleteMemo(id: memo.id)
        await service.waitForPendingOperations()
        XCTAssertTrue(memo.softDeleted)
        XCTAssertEqual(memo.syncState, .pendingDelete)
        XCTAssertEqual(service.pendingChangesCount(), 1)

        // Reconnect and sync: memo must be deleted on server, not resurrected.
        remote.errorToThrow = nil
        try await service.sync()
        XCTAssertTrue(remote.memos.isEmpty)
        XCTAssertTrue(memo.softDeleted)
        XCTAssertEqual(memo.syncState, .synced)
        XCTAssertEqual(service.pendingChangesCount(), 0)
        let remaining = try await service.listMemos()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testOfflineDeletePreservesRemoteWhenRemoteAlsoChanged() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        let memo = try await service.createMemo(content: "Original", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()

        // Edit remotely while client is offline and deletes locally.
        remote.memos[0].content = "Remote updated content"
        remote.memos[0].updatedAt = remote.memos[0].updatedAt.addingTimeInterval(60)
        remote.errorToThrow = URLError(.notConnectedToInternet)

        try await service.deleteMemo(id: memo.id)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.syncState, .pendingDelete)

        remote.errorToThrow = nil
        try await service.sync()
        XCTAssertEqual(remote.memos.count, 1)
        XCTAssertFalse(memo.softDeleted)
        XCTAssertEqual(memo.content, "Remote updated content")
        XCTAssertEqual(memo.syncState, .synced)
    }

    func testOfflineArchiveAndRestoreSyncProperly() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        let memo = try await service.createMemo(content: "Note", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.rowStatus, .normal)

        // Archive while offline.
        remote.errorToThrow = URLError(.notConnectedToInternet)
        try await service.archiveMemo(id: memo.id)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.rowStatus, .archived)
        XCTAssertEqual(memo.syncState, .pendingUpdate)
        XCTAssertEqual(service.pendingChangesCount(), 1)

        // Reconnect and sync -> server must archive memo and local stays archived.
        remote.errorToThrow = nil
        try await service.sync()
        XCTAssertEqual(remote.memos[0].rowStatus, .archived)
        XCTAssertEqual(memo.rowStatus, .archived)
        XCTAssertEqual(memo.syncState, .synced)
        XCTAssertEqual(remote.updateCallCount, 0, "RowStatus-only change should use archive endpoint without redundant updateMemo")

        // Restore while offline.
        remote.errorToThrow = URLError(.notConnectedToInternet)
        try await service.restoreMemo(id: memo.id)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.rowStatus, .normal)
        XCTAssertEqual(memo.syncState, .pendingUpdate)

        // Reconnect and sync -> server must restore memo.
        remote.errorToThrow = nil
        try await service.sync()
        XCTAssertEqual(remote.memos[0].rowStatus, .normal)
        XCTAssertEqual(memo.rowStatus, .normal)
        XCTAssertEqual(memo.syncState, .synced)
    }

    func testOfflineEditThenArchivePushesBothEditsAndArchivedState() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        let memo = try await service.createMemo(content: "Before edit", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()

        // Edit offline, then archive offline.
        remote.errorToThrow = URLError(.notConnectedToInternet)
        _ = try await service.updateMemo(id: memo.id, content: "After edit", resources: nil, visibility: nil, tags: nil, pinned: true)
        await service.waitForPendingOperations()
        try await service.archiveMemo(id: memo.id)
        await service.waitForPendingOperations()

        XCTAssertEqual(memo.content, "After edit")
        XCTAssertTrue(memo.pinned)
        XCTAssertEqual(memo.rowStatus, .archived)
        XCTAssertEqual(memo.syncState, .pendingUpdate)

        // Reconnect and sync -> BOTH content/pinned edits AND archived status must reach server.
        remote.errorToThrow = nil
        try await service.sync()
        XCTAssertEqual(remote.memos[0].content, "After edit")
        XCTAssertTrue(remote.memos[0].pinned)
        XCTAssertEqual(remote.memos[0].rowStatus, .archived)
        XCTAssertEqual(memo.content, "After edit")
        XCTAssertEqual(memo.rowStatus, .archived)
        XCTAssertEqual(memo.syncState, .synced)
    }

    func testOnlineArchiveAfterOfflineEditDoesNotDropPendingEdits() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        let memo = try await service.createMemo(content: "Initial", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()

        // Edit while offline.
        remote.errorToThrow = URLError(.notConnectedToInternet)
        _ = try await service.updateMemo(id: memo.id, content: "Updated content", resources: nil, visibility: nil, tags: nil, pinned: nil)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.syncState, .pendingUpdate)

        // Come back online and archive directly (without calling sync() first).
        remote.errorToThrow = nil
        try await service.archiveMemo(id: memo.id)
        await service.waitForPendingOperations()

        XCTAssertEqual(remote.memos[0].content, "Updated content")
        XCTAssertEqual(remote.memos[0].rowStatus, .archived)
        XCTAssertEqual(memo.syncState, .synced)
    }

    func testOfflineCreatePinnedAndArchivedPreservesBothOnPush() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        remote.errorToThrow = URLError(.notConnectedToInternet)
        let memo = try await service.createMemo(content: "Local new", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()
        _ = try await service.updateMemo(id: memo.id, content: nil, resources: nil, visibility: nil, tags: nil, pinned: true)
        await service.waitForPendingOperations()
        try await service.archiveMemo(id: memo.id)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.syncState, .pendingCreate)

        remote.errorToThrow = nil
        try await service.sync()

        XCTAssertEqual(remote.memos.count, 1)
        XCTAssertEqual(remote.memos[0].content, "Local new")
        XCTAssertTrue(remote.memos[0].pinned)
        XCTAssertEqual(remote.memos[0].rowStatus, .archived)
        XCTAssertEqual(memo.syncState, .synced)
        XCTAssertTrue(memo.pinned)
        XCTAssertEqual(memo.rowStatus, .archived)
    }

    func testDeleteMemoAlreadyGoneOnServer404MarksSynced() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        let memo = try await service.createMemo(content: "To delete", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()

        remote.deleteErrorToThrow = MoeMemosError.invalidStatusCode(404, "Not found")
        try await service.deleteMemo(id: memo.id)
        await service.waitForPendingOperations()

        XCTAssertTrue(memo.softDeleted)
        XCTAssertEqual(memo.syncState, .synced)
        XCTAssertEqual(service.pendingChangesCount(), 0)
        XCTAssertNil(service.lastSyncError)
    }

    func testDeletingMemoDiscardsAttachmentWhenUploadHasFailed() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        remote.createResourceErrorToThrow = MoeMemosError.invalidStatusCode(413, nil)
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")
        let store = LocalStore(context: container.mainContext, accountKey: "remote")
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([0]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let resource = store.createLocalResource(
            filename: "photo.png",
            size: 1,
            mimeType: "image/png",
            createdAt: .now,
            updatedAt: .now,
            urlString: fileURL.absoluteString,
            localPath: fileURL.path,
            syncState: .pendingCreate
        )
        try store.save()

        let memo = try await service.createMemo(content: "Attachment", visibility: .private, resources: [resource.id], tags: nil)
        await service.waitForPendingOperations()
        XCTAssertEqual(service.pendingChangesCount(), 2)
        XCTAssertNotNil(service.lastSyncError)

        remote.beforeCreateResource = {
            try await service.deleteMemo(id: memo.id)
            XCTAssertEqual(service.pendingChangesCount(), 0)
            XCTAssertNil(service.lastSyncError)
        }
        defer { remote.beforeCreateResource = nil }

        try await service.sync()

        XCTAssertTrue(resource.softDeleted)
        XCTAssertEqual(memo.syncState, .synced)
        XCTAssertEqual(service.pendingChangesCount(), 0)
        XCTAssertNil(service.lastSyncError)

        try await service.sync()
        XCTAssertEqual(remote.createResourceAttempts, 2)
        XCTAssertTrue(remote.memos.isEmpty)
    }

    func testSyncDiscardsPendingAttachmentOfPreviouslyDeletedMemo() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")
        let store = LocalStore(context: container.mainContext, accountKey: "remote")
        let memo = store.createLocalMemo(
            content: "Deleted",
            pinned: false,
            rowStatus: .normal,
            visibility: .private,
            createdAt: .now,
            updatedAt: .now,
            softDeleted: true,
            syncState: .synced
        )
        let resource = store.createLocalResource(
            filename: "photo.png",
            size: 1,
            mimeType: "image/png",
            createdAt: .now,
            updatedAt: .now,
            urlString: "file:///photo.png",
            memo: memo,
            syncState: .pendingCreate
        )
        try store.save()
        XCTAssertEqual(service.pendingChangesCount(), 1)

        try await service.sync()

        XCTAssertTrue(resource.softDeleted)
        XCTAssertEqual(service.pendingChangesCount(), 0)
        XCTAssertEqual(remote.createResourceAttempts, 0)
    }

    func testDeleteResourceFromNonSyncedStateMarksPendingDelete() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        let store = LocalStore(context: container.mainContext, accountKey: "remote")
        let resource = store.createLocalResource(
            serverId: "attachments/1",
            filename: "photo.png",
            size: 4,
            mimeType: "image/png",
            createdAt: .now,
            updatedAt: .now,
            urlString: "https://memos.example/file/attachments/1",
            syncState: .pendingUpdate
        )
        try store.save()

        remote.errorToThrow = URLError(.notConnectedToInternet)
        try await service.deleteResource(id: resource.id)
        await service.waitForPendingOperations()

        XCTAssertTrue(resource.softDeleted)
        XCTAssertEqual(resource.syncState, .pendingDelete)
        XCTAssertEqual(service.pendingChangesCount(), 1)

        remote.errorToThrow = nil
        try await service.sync()
        XCTAssertEqual(remote.deletedResourceIds, ["attachments/1"])
        XCTAssertEqual(resource.syncState, .synced)
        XCTAssertEqual(service.pendingChangesCount(), 0)
    }

    func testSyncAbortsOnAuthenticationErrorAndRecordsLastSyncError() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        remote.errorToThrow = URLError(.notConnectedToInternet)
        let memo1 = try await service.createMemo(content: "First", visibility: .private, resources: [], tags: nil)
        let memo2 = try await service.createMemo(content: "Second", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()

        remote.errorToThrow = nil
        remote.createAttempts = 0
        remote.createErrorToThrow = MoeMemosError.accessTokenExpired

        do {
            try await service.sync()
            XCTFail("Expected accessTokenExpired")
        } catch MoeMemosError.accessTokenExpired {
            // Expected
        }

        XCTAssertEqual(remote.createAttempts, 1, "Sync must abort immediately on auth error instead of retrying every pending item")
        XCTAssertEqual(memo1.syncState, .pendingCreate)
        XCTAssertEqual(memo2.syncState, .pendingCreate)
        XCTAssertEqual(service.lastSyncError.map(SyncErrorClassifier.classify), .authenticationRequired)
    }

    func testSyncPersistsSuccessfulItemsAndThrowsOnPartialTransientFailure() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        remote.memos = [Memo(content: "From server", remoteId: "memos/remote-1")]
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        remote.errorToThrow = URLError(.notConnectedToInternet)
        let localMemo = try await service.createMemo(content: "Offline memo", visibility: .private, resources: [], tags: nil)
        await service.waitForPendingOperations()

        remote.errorToThrow = nil
        remote.createErrorToThrow = MoeMemosError.invalidStatusCode(503, "Service Unavailable")

        do {
            try await service.sync()
            XCTFail("Expected 503 error to be surfaced")
        } catch MoeMemosError.invalidStatusCode(503, _) {
            // Expected
        }

        // Pulled remote memo must still have been saved, while failed local memo stays pending.
        let list = try await service.listMemos()
        XCTAssertEqual(Set(list.map(\.content)), Set(["From server", "Offline memo"]))
        XCTAssertEqual(localMemo.syncState, .pendingCreate)
        XCTAssertEqual(service.pendingChangesCount(), 1)
        XCTAssertEqual(service.lastSyncError.map(SyncErrorClassifier.classify), .transient)
    }

    func testStateChangeHandlerNotifiesOnBackgroundPushCompletion() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        var callbackCount = 0
        service.setStateChangeHandler {
            callbackCount += 1
        }

        _ = try await service.createMemo(content: "Notify me", visibility: .private, resources: [], tags: nil)
        let countAfterCreate = callbackCount
        XCTAssertGreaterThanOrEqual(countAfterCreate, 1)

        await service.waitForPendingOperations()
        XCTAssertGreaterThan(callbackCount, countAfterCreate)
        XCTAssertEqual(service.pendingChangesCount(), 0)
    }

    func testWaitForPendingOperationsWithTimeoutReturnsPromptlyWhenStalled() async throws {
        let container = try makeContainer()
        let remote = StubSyncRemote()
        remote.createDelay = .seconds(5)
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")

        _ = try await service.createMemo(content: "Slow push", visibility: .private, resources: [], tags: nil)

        let clock = ContinuousClock()
        let elapsed = await clock.measure {
            await service.waitForPendingOperations(timeout: .milliseconds(100))
        }
        XCTAssertLessThan(elapsed, .seconds(1))
    }
}

@MainActor
private final class StubSyncRemote: RemoteService {
    var errorToThrow: Error?
    var createErrorToThrow: Error?
    var createResourceErrorToThrow: Error?
    var beforeCreateResource: (() async throws -> Void)?
    var deleteErrorToThrow: Error?
    var createDelay: Duration?

    var memos: [Memo] = []
    var deletedResourceIds: [String] = []
    var updateCallCount = 0
    var createAttempts = 0
    var createResourceAttempts = 0
    private var nextId = 1

    var supportsMemoLocations: Bool { true }
    func memoVisibilities() -> [MemoVisibility] { [.private, .local, .public] }

    func listMemos() async throws -> [Memo] {
        if let error = errorToThrow { throw error }
        return memos.filter { $0.rowStatus == .normal }
    }

    func listArchivedMemos() async throws -> [Memo] {
        if let error = errorToThrow { throw error }
        return memos.filter { $0.rowStatus == .archived }
    }

    func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?) {
        ([], nil)
    }

    func createMemo(
        content: String,
        visibility: MemoVisibility?,
        resources: [Resource],
        tags: [String]?,
        createdAt: Date?,
        updatedAt: Date?,
        location: MemoLocation?
    ) async throws -> Memo {
        createAttempts += 1
        if let delay = createDelay {
            try? await Task.sleep(for: delay)
        }
        if let error = createErrorToThrow ?? errorToThrow { throw error }
        let memo = Memo(
            content: content,
            pinned: false,
            rowStatus: .normal,
            visibility: visibility ?? .private,
            resources: resources,
            createdAt: createdAt ?? .now,
            updatedAt: updatedAt ?? .now,
            remoteId: "memos/\(nextId)",
            location: location
        )
        nextId += 1
        memos.append(memo)
        return memo
    }

    func updateMemo(
        remoteId: String,
        content: String?,
        resources: [Resource]?,
        visibility: MemoVisibility?,
        tags: [String]?,
        pinned: Bool?,
        updatedAt: Date?,
        location: MemoLocationUpdate?
    ) async throws -> Memo {
        if let error = errorToThrow { throw error }
        updateCallCount += 1
        guard let index = memos.firstIndex(where: { $0.remoteId == remoteId }) else {
            throw MoeMemosError.invalidStatusCode(404, "Not found")
        }
        if let content { memos[index].content = content }
        if let resources { memos[index].resources = resources }
        if let visibility { memos[index].visibility = visibility }
        if let pinned { memos[index].pinned = pinned }
        if let location { memos[index].location = location.location }
        memos[index].updatedAt = updatedAt ?? .now
        return memos[index]
    }

    func deleteMemo(remoteId: String) async throws {
        if let error = deleteErrorToThrow ?? errorToThrow { throw error }
        memos.removeAll { $0.remoteId == remoteId }
    }

    func archiveMemo(remoteId: String) async throws {
        if let error = errorToThrow { throw error }
        guard let index = memos.firstIndex(where: { $0.remoteId == remoteId }) else {
            throw MoeMemosError.invalidStatusCode(404, "Not found")
        }
        memos[index].rowStatus = .archived
    }

    func restoreMemo(remoteId: String) async throws {
        if let error = errorToThrow { throw error }
        guard let index = memos.firstIndex(where: { $0.remoteId == remoteId }) else {
            throw MoeMemosError.invalidStatusCode(404, "Not found")
        }
        memos[index].rowStatus = .normal
    }

    func listTags() async throws -> [Tag] { [] }
    func listResources() async throws -> [Resource] { [] }

    func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource {
        createResourceAttempts += 1
        try await beforeCreateResource?()
        if let error = createResourceErrorToThrow ?? errorToThrow { throw error }
        return Resource(
            filename: filename,
            size: data.count,
            mimeType: type,
            createdAt: .now,
            updatedAt: .now,
            remoteId: "attachments/\(nextId)",
            url: URL(string: "https://memos.example/file/\(nextId)")!
        )
    }

    func deleteResource(remoteId: String) async throws {
        if let error = deleteErrorToThrow ?? errorToThrow { throw error }
        deletedResourceIds.append(remoteId)
    }

    func getCurrentUser() async throws -> UserSnapshot {
        if let error = errorToThrow { throw error }
        return UserSnapshot(accountKey: "remote", nickname: "Tester", remoteId: "1")
    }

    func download(url: URL, mimeType: String?) async throws -> URL {
        throw MoeMemosError.unknown
    }
}
