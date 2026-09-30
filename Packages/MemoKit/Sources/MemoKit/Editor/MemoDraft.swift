import Foundation
import Models
import SwiftData

struct MemoDraft: Codable, Equatable {
    var text: String
    var visibility: MemoVisibility
    var resourceIDs: [PersistentIdentifier]
}

/// Account-scoped drafts. Existing memo edits use a separate key from new memos.
struct MemoDraftStore {
    let defaults: UserDefaults
    let accountKey: String
    var memoID: PersistentIdentifier? = nil

    private var legacyKey: String { "draft.\(accountKey)" }

    private var key: String {
        // A storage key must be stable across encoder instances and app launches.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let suffix = memoID.flatMap { try? encoder.encode($0).base64EncodedString() } ?? "new"
        return "memoDraft.v1.\(accountKey).\(suffix)"
    }

    func load(defaultVisibility: MemoVisibility) -> MemoDraft? {
        if let data = defaults.data(forKey: key),
           let draft = try? JSONDecoder().decode(MemoDraft.self, from: data) {
            return draft
        }
        if memoID == nil, let text = defaults.string(forKey: legacyKey), !text.isEmpty {
            return MemoDraft(text: text, visibility: defaultVisibility, resourceIDs: [])
        }
        return nil
    }

    func save(_ draft: MemoDraft) throws {
        defaults.set(try JSONEncoder().encode(draft), forKey: key)
        if memoID == nil { defaults.removeObject(forKey: legacyKey) }
    }

    func clear() {
        defaults.removeObject(forKey: key)
        if memoID == nil { defaults.removeObject(forKey: legacyKey) }
    }
}
