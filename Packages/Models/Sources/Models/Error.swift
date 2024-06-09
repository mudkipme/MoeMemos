//
//  Error.swift
//
//
//  Created by Mudkip on 2023/11/18.
//

import Foundation

public enum MoeMemosError: LocalizedError {
    case unknown
    case notLogin
    case invalidStatusCode(Int, String?)
    case invalidParams
    case unsupportedVersion
    
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
        case .unsupportedVersion:
            return "Your Server version is not supported."
        }
    }
}
