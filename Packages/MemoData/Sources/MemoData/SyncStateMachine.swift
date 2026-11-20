import Foundation
import Models

public enum SyncErrorKind: Equatable, Sendable {
    case authenticationRequired
    case notFound
    case transient
    case permanent
}

public enum SyncErrorClassifier {
    public static func classify(_ error: Error) -> SyncErrorKind {
        if let memosError = error as? MoeMemosError {
            switch memosError {
            case .accessTokenExpired, .notLogin:
                return .authenticationRequired
            case .invalidStatusCode(let statusCode, _):
                switch statusCode {
                case 401, 403:
                    return .authenticationRequired
                case 404, 410:
                    return .notFound
                case 408, 429, 500...599:
                    return .transient
                default:
                    return .permanent
                }
            case .invalidParams, .fileTooLarge, .locationUnsupported, .unsupportedVersion, .accountCredentialSaveFailed:
                return .permanent
            case .unknown:
                return .transient
            }
        }

        if let urlError = error as? URLError {
            return classifyURLError(urlError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return classifyURLError(URLError(URLError.Code(rawValue: nsError.code)))
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return classify(underlying)
        }

        return .permanent
    }

    public static func isAlreadyDeletedOnServer(_ error: Error) -> Bool {
        classify(error) == .notFound
    }

    public static func shouldAbortSync(_ error: Error) -> Bool {
        classify(error) == .authenticationRequired
    }

    public static func shouldRetryAutomatically(_ error: Error) -> Bool {
        classify(error) == .transient
    }

    private static func classifyURLError(_ error: URLError) -> SyncErrorKind {
        switch error.code {
        case .notConnectedToInternet,
             .timedOut,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .dataNotAllowed,
             .callIsActive,
             .secureConnectionFailed,
             .cannotLoadFromNetwork,
             .backgroundSessionWasDisconnected,
             .backgroundSessionInUseByAnotherProcess:
            return .transient
        case .userAuthenticationRequired, .userCancelledAuthentication:
            return .authenticationRequired
        default:
            return .permanent
        }
    }
}

enum LocalDeletedResolution: Equatable, Sendable {
    case deleteOnServer
    case restoreFromRemote
}

enum BothPresentResolution: Equatable, Sendable {
    case markSynced
    case applyRemote
    case pushLocal
    case duplicateLocalAndApplyRemote
}

enum ServerDeletedResolution: Equatable, Sendable {
    case markLocalDeletedSynced
    case recreateOnServer
    case softDeleteLocal
}

enum SyncStateTransition {
    static func stateAfterUpdate(serverId: String?) -> SyncState {
        serverId == nil ? .pendingCreate : .pendingUpdate
    }

    static func stateAfterDelete(serverId: String?) -> SyncState {
        serverId != nil ? .pendingDelete : .synced
    }

    static func stateAfterRowStatusChange(serverId: String?, currentState: SyncState) -> (nextState: SyncState, requiresFullPush: Bool) {
        if serverId == nil {
            return (.pendingCreate, true)
        }
        if currentState != .synced {
            return (.pendingUpdate, true)
        }
        return (.pendingUpdate, false)
    }

    static func resolveLocalDeleted(
        syncState: SyncState,
        remoteChanged: Bool,
        remoteMatchesLocal: Bool
    ) -> LocalDeletedResolution {
        guard syncState == .pendingDelete else {
            return .restoreFromRemote
        }
        if remoteChanged && !remoteMatchesLocal {
            return .restoreFromRemote
        }
        return .deleteOnServer
    }

    static func resolveBothPresent(
        localChanged: Bool,
        remoteChanged: Bool,
        equivalent: Bool
    ) -> BothPresentResolution {
        if equivalent {
            return .markSynced
        }
        if !localChanged {
            return .applyRemote
        }
        if !remoteChanged {
            return .pushLocal
        }
        return .duplicateLocalAndApplyRemote
    }

    static func resolveServerDeleted(
        localSoftDeleted: Bool,
        localChanged: Bool
    ) -> ServerDeletedResolution {
        if localSoftDeleted {
            return .markLocalDeletedSynced
        }
        if localChanged {
            return .recreateOnServer
        }
        return .softDeleteLocal
    }
}
