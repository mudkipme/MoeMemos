import Foundation
import Models
import SwiftData
import XCTest
@testable import MemoData

@MainActor
final class MemoLocationTests: XCTestCase {
    private let place = MemoLocation(placeholder: "Singapore", latitude: 1.3521, longitude: 103.8198)

    private func container() throws -> ModelContainer {
        try ModelContainer(for: User.self, StoredMemo.self, StoredResource.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testLocalLocationPersistsAndUnrelatedEditsPreserveIt() async throws {
        let container = try container()
        let service: any Service = LocalService(context: container.mainContext, accountKey: "local")
        let memo = try await service.createMemo(content: "Here", visibility: .private, resources: [], tags: nil, location: place)
        let persisted = try ModelContext(container).fetch(FetchDescriptor<StoredMemo>()).first
        XCTAssertEqual(persisted?.location, place)
        _ = try await service.updateMemo(id: memo.id, content: "Updated", resources: [], visibility: nil, tags: nil, pinned: true)
        XCTAssertEqual(memo.location, place)
        _ = try await service.updateMemo(id: memo.id, content: nil, resources: nil, visibility: nil, tags: nil, pinned: nil, location: .remove)
        XCTAssertNil(memo.location)
        XCTAssertNil(memo.locationLatitude)
        XCTAssertNil(memo.locationLongitude)
    }

    func testOfflineCreateAndRemovalSyncWhenReconnected() async throws {
        let container = try container()
        let remote = LocationRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")
        remote.offline = true
        let memo = try await service.createMemo(content: "Offline", visibility: .private, resources: [], tags: nil, location: place)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.syncState, .pendingCreate)
        XCTAssertEqual(memo.location, place)
        remote.offline = false
        try await service.sync()
        XCTAssertEqual(memo.syncState, .synced)
        XCTAssertEqual(remote.memos.first?.location, place)
        XCTAssertEqual(memo.location, place)

        remote.offline = true
        _ = try await service.updateMemo(id: memo.id, content: nil, resources: nil, visibility: nil, tags: nil, pinned: nil, location: .remove)
        await service.waitForPendingOperations()
        XCTAssertEqual(memo.syncState, .pendingUpdate)
        XCTAssertNil(memo.location)
        remote.offline = false
        try await service.sync()
        XCTAssertEqual(remote.lastLocationUpdate, .remove)
        XCTAssertNil(remote.memos.first?.location)
        XCTAssertNil(memo.location)
        XCTAssertEqual(memo.syncState, .synced)
    }

    func testRemoteLocationChangesAndRemovalArePulled() async throws {
        let container = try container()
        let remote = LocationRemote()
        remote.memos = [Memo(content: "From web", remoteId: "memos/1", location: place)]
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")
        try await service.sync()
        let list = try await service.listMemos()
        let memo = try XCTUnwrap(list.first)
        XCTAssertEqual(memo.location, place)
        let equator = MemoLocation(latitude: 0, longitude: 0)
        remote.memos[0].location = equator
        remote.memos[0].updatedAt = memo.updatedAt.addingTimeInterval(10)
        try await service.sync()
        XCTAssertEqual(memo.location, equator)
        remote.memos[0].location = nil
        remote.memos[0].updatedAt = memo.updatedAt.addingTimeInterval(10)
        try await service.sync()
        XCTAssertNil(memo.location)
    }

    func testConcurrentLocationOnlyChangesPreserveBothVersions() async throws {
        let container = try container()
        let remote = LocationRemote()
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")
        let memo = try await service.createMemo(content: "Same text", visibility: .private, resources: [], tags: nil, location: place)
        await service.waitForPendingOperations()
        let localPlace = MemoLocation(placeholder: "New York", latitude: 40.71, longitude: -74.01)
        let remotePlace = MemoLocation(placeholder: "Tokyo", latitude: 35.68, longitude: 139.69)
        remote.offline = true
        _ = try await service.updateMemo(id: memo.id, content: nil, resources: nil, visibility: nil, tags: nil, pinned: nil, location: .set(localPlace))
        await service.waitForPendingOperations()
        remote.memos[0].location = remotePlace
        remote.memos[0].updatedAt = memo.updatedAt.addingTimeInterval(10)
        remote.offline = false
        try await service.sync()
        await service.waitForPendingOperations()
        let list = try await service.listMemos()
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(Set(list.compactMap(\.location)), Set([localPlace, remotePlace]))
        XCTAssertEqual(memo.location, remotePlace)
    }

    func testLegacyServerCannotSilentlyDropAnAttachedLocation() async throws {
        let container = try container()
        let remote = LocationRemote()
        remote.supportsMemoLocations = false
        let service = SyncingRemoteService(remote: remote, context: container.mainContext, accountKey: "remote")
        XCTAssertFalse(service.supportsMemoLocations)
        do {
            _ = try await service.createMemo(content: "Here", visibility: nil, resources: [], tags: nil, location: place)
            XCTFail("Location attachment must be rejected by a legacy account")
        } catch MoeMemosError.locationUnsupported {
            let list = try await service.listMemos()
            XCTAssertTrue(list.isEmpty)
        }
    }

    func testInvalidLocationCannotBeSaved() async throws {
        let container = try container()
        let service = LocalService(context: container.mainContext, accountKey: "local")
        do {
            _ = try await service.createMemo(content: "Invalid", visibility: nil, resources: [], tags: nil,
                                             location: MemoLocation(latitude: 91, longitude: 0))
            XCTFail("Out-of-range coordinates must be rejected")
        } catch {
            XCTAssertTrue(error is MoeMemosError)
        }
        let list = try await service.listMemos()
        XCTAssertTrue(list.isEmpty)
    }
}

@MainActor
private final class LocationRemote: RemoteService {
    var supportsMemoLocations = true
    var offline = false
    var memos: [Memo] = []
    var lastLocationUpdate: MemoLocationUpdate?

    private func checkConnection() throws {
        if offline { throw URLError(.notConnectedToInternet) }
    }
    func memoVisibilities() -> [MemoVisibility] { [.private] }
    func listMemos() async throws -> [Memo] { try checkConnection(); return memos }
    func listArchivedMemos() async throws -> [Memo] { [] }
    func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?) { ([], nil) }
    func createMemo(content: String, visibility: MemoVisibility?, resources: [Resource], tags: [String]?, createdAt: Date?, updatedAt: Date?, location: MemoLocation?) async throws -> Memo {
        try checkConnection()
        let memo = Memo(content: content, visibility: visibility ?? .private, resources: resources,
                        createdAt: createdAt ?? .now, updatedAt: updatedAt ?? .now,
                        remoteId: "memos/\(UUID().uuidString)", location: location)
        memos.append(memo)
        return memo
    }
    func updateMemo(remoteId: String, content: String?, resources: [Resource]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?, updatedAt: Date?, location: MemoLocationUpdate?) async throws -> Memo {
        try checkConnection()
        guard let index = memos.firstIndex(where: { $0.remoteId == remoteId }) else { throw MoeMemosError.invalidParams }
        if let content { memos[index].content = content }
        if let visibility { memos[index].visibility = visibility }
        if let pinned { memos[index].pinned = pinned }
        if let resources { memos[index].resources = resources }
        if let location { memos[index].location = location.location }
        memos[index].updatedAt = updatedAt ?? .now
        lastLocationUpdate = location
        return memos[index]
    }
    func getCurrentUser() async throws -> UserSnapshot { try checkConnection(); return .local(accountKey: "remote") }
    func deleteMemo(remoteId: String) async throws { throw MoeMemosError.unknown }
    func archiveMemo(remoteId: String) async throws { throw MoeMemosError.unknown }
    func restoreMemo(remoteId: String) async throws { throw MoeMemosError.unknown }
    func listTags() async throws -> [Tag] { [] }
    func listResources() async throws -> [Resource] { [] }
    func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource { throw MoeMemosError.unknown }
    func deleteResource(remoteId: String) async throws { throw MoeMemosError.unknown }
    func download(url: URL, mimeType: String?) async throws -> URL { throw MoeMemosError.unknown }
}
