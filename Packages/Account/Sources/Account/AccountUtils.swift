//
//  AccountUtils.swift
//
//
//  Created by Mudkip on 2024/6/15.
//

import Foundation
import MemosV0Service
import MemosV1Service
import Models

public var moeMemosSupportedMemosVersionsMessage: String {
    SupportedMemosVersion.localizedSupportedVersionsMessage()
}

public var moeMemosHigherMemosVersionLoginWarning: String {
    NSLocalizedString("compat.higher-version.login-warning", comment: "Warning shown before login on newer Memos versions")
}

public var moeMemosHigherMemosVersionSyncWarning: String {
    NSLocalizedString("compat.higher-version.sync-warning", comment: "Warning shown before forcing sync on newer Memos versions")
}

public enum MemosVersion {
    case v0(version: String)
    case v1(version: String)
    
    public var version: String {
        switch self {
        case .v0(version: let ver):
            return ver
        case .v1(version: let ver):
            return ver
        }
    }
}

public enum MemosVersionCompatibility: Equatable, Sendable {
    case supported
    case unsupported
    case v1HigherThanSupported(version: String)
}

public func detectMemosVersion(hostURL: URL) async throws -> MemosVersion {
    let v0Service = MemosV0Service(hostURL: hostURL, accessToken: nil)
    let v0Status = try? await v0Service.getStatus()
    if let version = v0Status?.profile?.version, !version.isEmpty {
        return .v0(version: version)
    }

    let v1Service = MemosV1Service(hostURL: hostURL, accessToken: nil, userId: nil)
    let v1Profile = try await v1Service.getWorkspaceProfile()
    if let version = v1Profile.version, !version.isEmpty {
        return .v1(version: version)
    }
    throw MoeMemosError.unsupportedVersion
}

public func detectMemosVersion(account: Account) async throws -> MemosVersion {
    switch account {
    case .local:
        throw MoeMemosError.notLogin
    case let .memosV0(host: host, id: _, accessToken: accessToken):
        guard let hostURL = URL(string: host) else {
            throw MoeMemosError.invalidParams
        }
        let service = MemosV0Service(hostURL: hostURL, accessToken: accessToken)
        let status = try await service.getStatus()
        guard let version = status.profile?.version, !version.isEmpty else {
            throw MoeMemosError.unsupportedVersion
        }
        return .v0(version: version)
    case let .memosV1(host: host, id: _, accessToken: accessToken):
        guard let hostURL = URL(string: host) else {
            throw MoeMemosError.invalidParams
        }
        let service = MemosV1Service(hostURL: hostURL, accessToken: accessToken, userId: nil)
        let profile = try await service.getWorkspaceProfile()
        guard let version = profile.version, !version.isEmpty else {
            throw MoeMemosError.unsupportedVersion
        }
        return .v1(version: version)
    }
}

public func evaluateMemosVersionCompatibility(_ version: MemosVersion) -> MemosVersionCompatibility {
    guard let minimumV0 = SemanticVersion(SupportedMemosVersion.minimumV0),
          let minimumV1 = SemanticVersion(SupportedMemosVersion.minimumV1),
          let maximumV1 = SemanticVersion(SupportedMemosVersion.maximumV1) else {
        return .unsupported
    }

    switch version {
    case .v0(version: let raw):
        guard let semver = SemanticVersion(raw) else {
            return .unsupported
        }
        return semver < minimumV0 ? .unsupported : .supported
    case .v1(version: let raw):
        guard let semver = SemanticVersion(raw) else {
            return .unsupported
        }
        if semver < minimumV1 {
            return .unsupported
        }
        if semver > maximumV1 {
            return .v1HigherThanSupported(version: raw)
        }
        return .supported
    }
}

private struct SemanticVersion: Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ raw: String) {
        var components = [Int]()
        var current = ""

        for char in raw {
            if char.isNumber {
                current.append(char)
                continue
            }
            if !current.isEmpty {
                if let value = Int(current) {
                    components.append(value)
                    if components.count == 3 {
                        break
                    }
                }
                current = ""
            }
        }

        if components.count < 3, !current.isEmpty, let value = Int(current) {
            components.append(value)
        }

        guard components.count >= 2 else {
            return nil
        }

        let major = components[0]
        let minor = components[1]
        let patch = components.count >= 3 ? components[2] : 0
        self.init(major: major, minor: minor, patch: patch)
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}
