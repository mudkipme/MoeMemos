//
//  Account.swift
//  
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation

public enum Account: Codable {
    case local
    case memos(host: String, id: String, accessToken: String)
    
    public var key: String {
        switch self {
        case .local:
            return "local"
        case let .memos(host: host, id: id, accessToken: _):
            return "memos:\(host):\(id)"
        }
    }
}
