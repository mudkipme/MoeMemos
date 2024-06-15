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

enum MemosVersion {
    case v0(version: String)
    case v1(version: String)
    
    var version: String? {
        switch self {
        case .v0(version: let ver):
            return ver
        case .v1(version: let ver):
            return ver
        }
    }
}

func detectMemosVersion(hostURL: URL) async throws -> MemosVersion {
    let v1Service = MemosV1Service(hostURL: hostURL, accessToken: nil, userId: nil)
    let v1Profile = try? await v1Service.getWorkspaceProfile()
    if let version = v1Profile?.version, !version.isEmpty {
        return .v1(version: version)
    }
    let v0Service = MemosV0Service(hostURL: hostURL, accessToken: nil)
    let v0Status = try? await v0Service.getStatus()
    if let version = v0Status?.profile?.version, !version.isEmpty {
        return .v0(version: version)
    }
    throw MoeMemosError.unsupportedVersion
}
