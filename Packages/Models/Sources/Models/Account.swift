//
//  Account.swift
//  
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation

public enum Account: Codable, Sendable {
    case local
    case memosV0(host: String, id: String, accessToken: String)
    case memosV1(host: String, id: String, accessToken: String)
    case blinkoV1(host: String, id: String, accessToken: String)
    
    public var key: String {
        switch self {
        case .local:
            return "local"
        case let .memosV0(host: host, id: id, accessToken: _):
            return "memos:\(host):\(id)"
        case let .memosV1(host: host, id: id, accessToken: _):
            return "memos:\(host):\(id)"
        case let .blinkoV1(host: host, id: id, accessToken: _):
            return "blinko:\(host):\(id)"
        }
    }
}

extension Account: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.key == rhs.key
    }
}
