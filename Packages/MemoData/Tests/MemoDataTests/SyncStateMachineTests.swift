import Foundation
import Models
import XCTest
@testable import MemoData

final class SyncStateMachineTests: XCTestCase {
    func testErrorClassifierIdentifiesAuthenticationErrors() {
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.accessTokenExpired), .authenticationRequired)
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.notLogin), .authenticationRequired)
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.invalidStatusCode(401, "Unauthorized")), .authenticationRequired)
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.invalidStatusCode(403, "Forbidden")), .authenticationRequired)
        XCTAssertTrue(SyncErrorClassifier.shouldAbortSync(MoeMemosError.accessTokenExpired))
        XCTAssertFalse(SyncErrorClassifier.shouldRetryAutomatically(MoeMemosError.accessTokenExpired))
    }

    func testErrorClassifierIdentifiesNotFoundErrors() {
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.invalidStatusCode(404, "Not found")), .notFound)
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.invalidStatusCode(410, "Gone")), .notFound)
        XCTAssertTrue(SyncErrorClassifier.isAlreadyDeletedOnServer(MoeMemosError.invalidStatusCode(404, nil)))
        XCTAssertFalse(SyncErrorClassifier.shouldAbortSync(MoeMemosError.invalidStatusCode(404, nil)))
    }

    func testErrorClassifierIdentifiesTransientErrors() {
        XCTAssertEqual(SyncErrorClassifier.classify(URLError(.notConnectedToInternet)), .transient)
        XCTAssertEqual(SyncErrorClassifier.classify(URLError(.timedOut)), .transient)
        XCTAssertEqual(SyncErrorClassifier.classify(URLError(.networkConnectionLost)), .transient)
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.invalidStatusCode(429, nil)), .transient)
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.invalidStatusCode(503, nil)), .transient)
        XCTAssertTrue(SyncErrorClassifier.shouldRetryAutomatically(URLError(.notConnectedToInternet)))

        let wrapped = NSError(
            domain: "WrapperDomain",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: URLError(.timedOut)]
        )
        XCTAssertEqual(SyncErrorClassifier.classify(wrapped), .transient)
    }

    func testErrorClassifierIdentifiesPermanentErrors() {
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.invalidParams), .permanent)
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.locationUnsupported), .permanent)
        XCTAssertEqual(SyncErrorClassifier.classify(MoeMemosError.invalidStatusCode(400, "Bad Request")), .permanent)
        XCTAssertFalse(SyncErrorClassifier.shouldRetryAutomatically(MoeMemosError.invalidParams))
    }

    func testStateTransitionsForUpdateDeleteAndRowStatus() {
        XCTAssertEqual(SyncStateTransition.stateAfterUpdate(serverId: nil), .pendingCreate)
        XCTAssertEqual(SyncStateTransition.stateAfterUpdate(serverId: "memos/1"), .pendingUpdate)

        XCTAssertEqual(SyncStateTransition.stateAfterDelete(serverId: nil), .synced)
        XCTAssertEqual(SyncStateTransition.stateAfterDelete(serverId: "memos/1"), .pendingDelete)

        let localArchive = SyncStateTransition.stateAfterRowStatusChange(serverId: nil, currentState: .pendingCreate)
        XCTAssertEqual(localArchive.nextState, .pendingCreate)
        XCTAssertTrue(localArchive.requiresFullPush)

        let cleanArchive = SyncStateTransition.stateAfterRowStatusChange(serverId: "memos/1", currentState: .synced)
        XCTAssertEqual(cleanArchive.nextState, .pendingUpdate)
        XCTAssertFalse(cleanArchive.requiresFullPush)

        let dirtyArchive = SyncStateTransition.stateAfterRowStatusChange(serverId: "memos/1", currentState: .pendingUpdate)
        XCTAssertEqual(dirtyArchive.nextState, .pendingUpdate)
        XCTAssertTrue(dirtyArchive.requiresFullPush)
    }

    func testResolveLocalDeletedHonorsDeleteWhenRemoteUnchangedEvenAfterOfflineEdits() {
        // Offline edit then offline delete, remote untouched -> delete on server.
        XCTAssertEqual(
            SyncStateTransition.resolveLocalDeleted(syncState: .pendingDelete, remoteChanged: false, remoteMatchesLocal: false),
            .deleteOnServer
        )
        // Normal offline delete -> delete on server.
        XCTAssertEqual(
            SyncStateTransition.resolveLocalDeleted(syncState: .pendingDelete, remoteChanged: false, remoteMatchesLocal: true),
            .deleteOnServer
        )
        // Remote modified differently since last sync -> preserve remote.
        XCTAssertEqual(
            SyncStateTransition.resolveLocalDeleted(syncState: .pendingDelete, remoteChanged: true, remoteMatchesLocal: false),
            .restoreFromRemote
        )
        // Remote updatedAt changed but content identical to deleted memo -> delete on server.
        XCTAssertEqual(
            SyncStateTransition.resolveLocalDeleted(syncState: .pendingDelete, remoteChanged: true, remoteMatchesLocal: true),
            .deleteOnServer
        )
        // Soft-deleted row not marked pendingDelete -> never delete server data.
        XCTAssertEqual(
            SyncStateTransition.resolveLocalDeleted(syncState: .synced, remoteChanged: false, remoteMatchesLocal: true),
            .restoreFromRemote
        )
    }

    func testResolveBothPresentAndServerDeleted() {
        XCTAssertEqual(SyncStateTransition.resolveBothPresent(localChanged: true, remoteChanged: true, equivalent: true), .markSynced)
        XCTAssertEqual(SyncStateTransition.resolveBothPresent(localChanged: false, remoteChanged: true, equivalent: false), .applyRemote)
        XCTAssertEqual(SyncStateTransition.resolveBothPresent(localChanged: true, remoteChanged: false, equivalent: false), .pushLocal)
        XCTAssertEqual(SyncStateTransition.resolveBothPresent(localChanged: true, remoteChanged: true, equivalent: false), .duplicateLocalAndApplyRemote)

        XCTAssertEqual(SyncStateTransition.resolveServerDeleted(localSoftDeleted: true, localChanged: false), .markLocalDeletedSynced)
        XCTAssertEqual(SyncStateTransition.resolveServerDeleted(localSoftDeleted: false, localChanged: true), .recreateOnServer)
        XCTAssertEqual(SyncStateTransition.resolveServerDeleted(localSoftDeleted: false, localChanged: false), .softDeleteLocal)
    }
}
