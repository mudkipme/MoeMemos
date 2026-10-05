import Foundation
import SwiftData

/// Local identity is independent of the server ID assigned after an offline create.
public struct MemoEntityIdentifier: Codable, Hashable, Sendable {
    public let accountKey: String
    public let persistentID: PersistentIdentifier

    public init(accountKey: String, persistentID: PersistentIdentifier) {
        self.accountKey = accountKey
        self.persistentID = persistentID
    }

    public var token: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self))?.base64EncodedString()
    }

    public init?(token: String) {
        guard let data = Data(base64Encoded: token),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = value
    }
}

