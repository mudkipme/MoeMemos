//
//  Error.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

enum MemosError: LocalizedError {
    case unknown
    case notLogin
    case invalidStatusCode(Int, String?)
    case invalidParams
    
    public var errorDescription: String? {
        switch self {
        case .unknown:
            return "Unknown error."
        case .notLogin:
            return "You are logged out."
        case .invalidStatusCode(_, let message):
            if let message = message {
                return message
            }
            return "Network error."
        case .invalidParams:
            return "Please enter a valid input."
        }
    }
}
