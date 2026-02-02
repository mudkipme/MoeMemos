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
    case fileTooLarge(Int64)
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
        case .fileTooLarge(let maxBytes):
            return "File is too large. Max size is \(formatByteCount(maxBytes))."
        case .unsupportedVersion:
            return "Your Server version is not supported."
        }
    }

    private func formatByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
