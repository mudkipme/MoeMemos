import Foundation
import Models
import SwiftData
import XCTest
@testable import MemoData

@MainActor
final class SyncingRemoteServiceTests: XCTestCase {
    func testOverlappingRequestsShareCanonicalFileAndRedownloadIfRemoved() async throws {
        let fixture = try ResourceDownloadFixture()
        defer { fixture.cleanup() }
        let resource = try fixture.resource()
        let first = Task { try await fixture.service.ensureLocalResourceFile(id: resource.persistentModelID) }
        let started = await XCTWaiter.fulfillment(of: [fixture.remote.downloadStarted], timeout: 5)
        XCTAssertEqual(started, .completed)

        let secondStarted = XCTestExpectation(description: "Second caller entered")
        let second = Task { @MainActor in
            // There is no suspension between this signal and the same-actor call.
            // The test regains MainActor only after that call suspends.
            secondStarted.fulfill()
            return try await fixture.service.ensureLocalResourceFile(id: resource.persistentModelID)
        }
        let overlapped = await XCTWaiter.fulfillment(of: [secondStarted], timeout: 5)
        XCTAssertEqual(overlapped, .completed)
        XCTAssertEqual(fixture.remote.downloadCount, 1)

        // Release every admitted call, including both calls on the unfixed implementation.
        fixture.remote.completeDownloads()
        let firstResult = await first.result
        let secondResult = await second.result
        let firstURL = try firstResult.get()
        let secondURL = try secondResult.get()
        XCTAssertEqual(firstURL, secondURL)
        XCTAssertEqual(resource.localPath, firstURL.path)
        XCTAssertEqual(resource.urlString, fixture.remoteURL.absoluteString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertEqual(try Data(contentsOf: firstURL), fixture.contents)
        let cachedURL = try await fixture.service.ensureLocalResourceFile(id: resource.persistentModelID)
        XCTAssertEqual(cachedURL, firstURL)
        XCTAssertEqual(fixture.remote.downloadCount, 1)

        try FileManager.default.removeItem(at: firstURL)
        fixture.remote.holdDownloads = false
        let replacement = try await fixture.service.ensureLocalResourceFile(id: resource.persistentModelID)
        XCTAssertEqual(fixture.remote.downloadCount, 2)
        XCTAssertNotEqual(replacement, firstURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: replacement.path))
        XCTAssertEqual(resource.localPath, replacement.path)
    }

    func testFailedDownloadCanBeRetried() async throws {
        let fixture = try ResourceDownloadFixture()
        defer { fixture.cleanup() }
        let resource = try fixture.resource()
        fixture.remote.failure = URLError(.notConnectedToInternet)
        do {
            _ = try await fixture.service.ensureLocalResourceFile(id: resource.persistentModelID)
            XCTFail("The first download should fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
        XCTAssertNil(resource.localPath)

        fixture.remote.failure = nil
        fixture.remote.holdDownloads = false
        let url = try await fixture.service.ensureLocalResourceFile(id: resource.persistentModelID)
        XCTAssertEqual(fixture.remote.downloadCount, 2)
        XCTAssertEqual(resource.localPath, url.path)
        XCTAssertEqual(try Data(contentsOf: url), fixture.contents)
    }

    func testDifferentResourcesWithSameRemoteURLDownloadIndependently() async throws {
        let fixture = try ResourceDownloadFixture()
        defer { fixture.cleanup() }
        let firstResource = try fixture.resource()
        let secondResource = try fixture.resource()
        let first = Task { try await fixture.service.ensureLocalResourceFile(id: firstResource.persistentModelID) }
        let started = await XCTWaiter.fulfillment(of: [fixture.remote.downloadStarted], timeout: 5)
        XCTAssertEqual(started, .completed)

        let second = Task { try await fixture.service.ensureLocalResourceFile(id: secondResource.persistentModelID) }
        let overlapped = await XCTWaiter.fulfillment(of: [fixture.remote.secondDownloadStarted], timeout: 5)
        XCTAssertEqual(overlapped, .completed)
        XCTAssertEqual(fixture.remote.downloadCount, 2)
        fixture.remote.completeDownloads()
        let firstResult = await first.result
        let secondResult = await second.result
        let firstURL = try firstResult.get()
        let secondURL = try secondResult.get()
        XCTAssertNotEqual(firstURL, secondURL)
        XCTAssertEqual(firstResource.localPath, firstURL.path)
        XCTAssertEqual(secondResource.localPath, secondURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
    }

    func testCancellingOneWaiterDoesNotCancelAnotherActiveWaiter() async throws {
        let fixture = try ResourceDownloadFixture()
        defer { fixture.cleanup() }
        let resource = try fixture.resource()
        let first = Task { try await fixture.service.ensureLocalResourceFile(id: resource.persistentModelID) }
        let started = await XCTWaiter.fulfillment(of: [fixture.remote.downloadStarted], timeout: 5)
        XCTAssertEqual(started, .completed)

        let secondStarted = XCTestExpectation(description: "Active second waiter entered")
        let second = Task { @MainActor in
            secondStarted.fulfill()
            return try await fixture.service.ensureLocalResourceFile(id: resource.persistentModelID)
        }
        let overlapped = await XCTWaiter.fulfillment(of: [secondStarted], timeout: 5)
        XCTAssertEqual(overlapped, .completed)
        first.cancel()
        fixture.remote.completeDownloads()
        _ = await first.result
        let activeResult = await second.result
        let url = try activeResult.get()
        XCTAssertEqual(fixture.remote.downloadCount, 1)
        XCTAssertEqual(fixture.remote.cancelledDownloadCount, 0)
        XCTAssertEqual(resource.localPath, url.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}

@MainActor
private final class ResourceDownloadFixture {
    let accountKey: String
    let remoteURL = URL(string: "https://example.invalid/shared.png")!
    let contents: Data
    let context: ModelContext
    let remote: ControlledDownloadRemote
    let service: SyncingRemoteService
    private let temporaryDirectory: URL

    init() throws {
        let accountKey = "ResourceDownloadTests-\(UUID().uuidString)"
        let contents = Data([0, 1, 2, 255, 42])
        let context = ModelContext(try ModelContainer(for: User.self, StoredMemo.self, StoredResource.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let remote = ControlledDownloadRemote(directory: temporaryDirectory, contents: contents)
        self.accountKey = accountKey
        self.contents = contents
        self.context = context
        self.temporaryDirectory = temporaryDirectory
        self.remote = remote
        service = SyncingRemoteService(remote: remote, context: context, accountKey: accountKey)
        // Fail before launching any task if the test host cannot use the real app-group store.
        do {
            let probe = try ResourceFileStore.store(data: contents, filename: "probe", mimeType: "image/png",
                accountKey: accountKey, resourceId: "probe")
            ResourceFileStore.deleteFile(at: probe)
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        } catch {
            ResourceFileStore.deleteAccountFiles(accountKey: accountKey)
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw error
        }
    }

    func resource() throws -> StoredResource {
        let resource = StoredResource(accountKey: accountKey, serverId: UUID().uuidString,
            filename: "image.png", size: contents.count, mimeType: "image/png", createdAt: .now,
            updatedAt: .now, urlString: remoteURL.absoluteString)
        context.insert(resource)
        try context.save()
        return resource
    }

    func cleanup() {
        remote.completeDownloads()
        ResourceFileStore.deleteAccountFiles(accountKey: accountKey)
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}

@MainActor
private final class ControlledDownloadRemote: RemoteService {
    let downloadStarted = XCTestExpectation(description: "First download started")
    let secondDownloadStarted = XCTestExpectation(description: "Second download started")
    private(set) var downloadCount = 0
    private(set) var cancelledDownloadCount = 0
    var holdDownloads = true
    var failure: Error?
    private let directory: URL
    private let contents: Data
    private var pending: [(CheckedContinuation<URL, Error>, URL)] = []

    init(directory: URL, contents: Data) {
        self.directory = directory
        self.contents = contents
    }

    func download(url: URL, mimeType: String?) async throws -> URL {
        downloadCount += 1
        if downloadCount == 1 { downloadStarted.fulfill() }
        if downloadCount == 2 { secondDownloadStarted.fulfill() }
        if let failure { throw failure }
        let source = directory.appendingPathComponent(UUID().uuidString)
        try contents.write(to: source)
        let result: URL
        if holdDownloads {
            result = try await withCheckedThrowingContinuation { pending.append(($0, source)) }
        } else {
            result = source
        }
        if Task.isCancelled {
            cancelledDownloadCount += 1
            throw CancellationError()
        }
        return result
    }

    func completeDownloads() {
        // Future calls also finish, so a faulty implementation cannot strand an extra waiter.
        holdDownloads = false
        let downloads = pending
        pending.removeAll()
        for (continuation, source) in downloads { continuation.resume(returning: source) }
    }

    func memoVisibilities() -> [MemoVisibility] { fatalError("Unexpected memoVisibilities") }
    func listMemos() async throws -> [Memo] { fatalError("Unexpected listMemos") }
    func listArchivedMemos() async throws -> [Memo] { fatalError("Unexpected listArchivedMemos") }
    func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?) {
        fatalError("Unexpected listWorkspaceMemos")
    }
    func createMemo(content: String, visibility: MemoVisibility?, resources: [Resource], tags: [String]?,
        createdAt: Date?, updatedAt: Date?) async throws -> Memo { fatalError("Unexpected createMemo") }
    func updateMemo(remoteId: String, content: String?, resources: [Resource]?, visibility: MemoVisibility?,
        tags: [String]?, pinned: Bool?, updatedAt: Date?) async throws -> Memo { fatalError("Unexpected updateMemo") }
    func deleteMemo(remoteId: String) async throws { fatalError("Unexpected deleteMemo") }
    func archiveMemo(remoteId: String) async throws { fatalError("Unexpected archiveMemo") }
    func restoreMemo(remoteId: String) async throws { fatalError("Unexpected restoreMemo") }
    func listTags() async throws -> [Tag] { fatalError("Unexpected listTags") }
    func listResources() async throws -> [Resource] { fatalError("Unexpected listResources") }
    func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource {
        fatalError("Unexpected createResource")
    }
    func deleteResource(remoteId: String) async throws { fatalError("Unexpected deleteResource") }
    func getCurrentUser() async throws -> UserSnapshot { fatalError("Unexpected getCurrentUser") }
}
