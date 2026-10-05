import MemoData
import AppIntents
import CoreSpotlight
import CoreTransferable
import Foundation
import Models
import SwiftData
import UniformTypeIdentifiers

public struct MemoEntity: IndexedEntity, Transferable {
    public static let persistentIdentifier = "MemoEntity"
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Memo"
    public static let defaultQuery = MemoEntityQuery()
    public static let defaultIntent = OpenMemoIntent.self

    public let id: String
    public let accountKey: String
    public let attachments: [IntentFile]
    @Property(title: "Content") public var content: String
    @Property(title: "Account") public var accountName: String
    @Property(title: "Created") public var createdAt: Date
    @Property(title: "Modified") public var updatedAt: Date
    @Property(title: "Pinned") public var isPinned: Bool
    @Property(title: "Tags") public var tags: [String]

    public var title: String {
        let firstLine = content.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let title = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? String(localized: "Memo") : String(title.prefix(100))
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(accountName)")
    }

    public var url: URL {
        var url = URLComponents()
        url.scheme = "moememos"
        url.host = "memo"
        url.queryItems = [URLQueryItem(name: "entity_id", value: id)]
        return url.url!
    }

    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = title
        attributes.contentDescription = content
        attributes.textContent = content
        attributes.keywords = tags
        attributes.contentCreationDate = createdAt
        attributes.contentModificationDate = updatedAt
        attributes.contentURL = url
        attributes.relatedUniqueIdentifier = id
        return attributes
    }

    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.content)
    }

    @MainActor
    public init?(memo: StoredMemo, accountName: String) {
        guard !memo.softDeleted, memo.rowStatus == .normal,
              let id = MemoEntityIdentifier(accountKey: memo.accountKey, persistentID: memo.id).token else { return nil }
        self.id = id
        self.accountKey = memo.accountKey
        self.attachments = memo.resources.filter { !$0.softDeleted }.compactMap { resource in
            guard let path = resource.localPath, FileManager.default.fileExists(atPath: path) else { return nil }
            return IntentFile(fileURL: URL(fileURLWithPath: path), filename: resource.filename)
        }
        self.content = memo.content
        self.accountName = accountName
        self.createdAt = memo.createdAt
        self.updatedAt = memo.updatedAt
        self.isPinned = memo.pinned
        self.tags = MemoTagExtractor.extract(from: memo.content)
    }
}

public struct MemoEntityQuery: EntityStringQuery {
    public static let persistentIdentifier = "MemoEntity"
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [MemoEntity] {
        try await MainActor.run {
            try MemoEntityStore(context: AppInfo().modelContext).entities(for: identifiers)
        }
    }

    public func entities(matching string: String) async throws -> [MemoEntity] {
        try await MainActor.run {
            try MemoEntityStore(context: AppInfo().modelContext).search(string)
        }
    }

    public func suggestedEntities() async throws -> [MemoEntity] {
        try await entities(matching: "")
    }
}

/// Reads local data only; entity resolution must never initiate a remote sync.
@MainActor
public struct MemoEntityStore {
    public static let persistentIdentifier = "MemoEntity"
    let context: ModelContext
    private let accountAvailable: (String) -> Bool

    public init(context: ModelContext, accountAvailable: @escaping (String) -> Bool = { Account.retrieve(accountKey: $0) != nil }) {
        self.context = context
        self.accountAvailable = accountAvailable
    }

    func accountNames() throws -> [String: String] {
        let users = try context.fetch(FetchDescriptor<User>())
        return users.reduce(into: [:]) { result, user in
            if accountAvailable(user.accountKey) { result[user.accountKey] = user.nickname }
        }
    }

    public func memo(for identifier: String) throws -> StoredMemo? {
        guard let key = MemoEntityIdentifier(token: identifier),
              try accountNames()[key.accountKey] != nil,
              let memo = try storedMemo(id: key.persistentID),
              memo.accountKey == key.accountKey, !memo.softDeleted, memo.rowStatus == .normal else { return nil }
        return memo
    }

    public func entities(for identifiers: [String]) throws -> [MemoEntity] {
        let names = try accountNames()
        return try identifiers.compactMap { id in
            guard let key = MemoEntityIdentifier(token: id), let name = names[key.accountKey],
                  let memo = try storedMemo(id: key.persistentID),
                  memo.accountKey == key.accountKey else { return nil }
            return MemoEntity(memo: memo, accountName: name)
        }
    }

    /// Preserve identifiers stored by existing pinned widgets while sharing resolution rules.
    public func entity(forLegacyIdentifier identifier: String) throws -> MemoEntity? {
        guard let id = PersistentIdentifierTokenCoder.decode(identifier),
              let memo = try storedMemo(id: id),
              let name = try accountNames()[memo.accountKey] else { return nil }
        return MemoEntity(memo: memo, accountName: name)
    }

    private func storedMemo(id: PersistentIdentifier) throws -> StoredMemo? {
        // model(for:) can return a fault for a deleted record. Fetch to verify existence.
        var descriptor = FetchDescriptor<StoredMemo>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    public func allEntities() throws -> [MemoEntity] {
        let names = try accountNames()
        let descriptor = FetchDescriptor<StoredMemo>(
            predicate: #Predicate { !$0.softDeleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).compactMap { memo in
            guard let name = names[memo.accountKey] else { return nil }
            return MemoEntity(memo: memo, accountName: name)
        }
    }

    public func search(_ text: String, limit: Int = 100) throws -> [MemoEntity] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return Array(try allEntities().filter {
            query.isEmpty || $0.content.localizedStandardContains(query)
        }.prefix(limit))
    }
}
