//
//  PersistentIdentifierTokenCoder.swift
//
//
//  Created by Codex on 2026/2/26.
//

import Foundation
import SwiftData

public enum PersistentIdentifierTokenCoder {
    public static func encode(_ identifier: some Encodable) -> String? {
        guard let encoded = try? JSONEncoder().encode(identifier) else {
            return nil
        }
        return encoded.base64EncodedString()
    }

    public static func decode(_ token: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: token) else {
            return nil
        }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}
