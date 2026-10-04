import MemoData
import AppIntents
import CoreSpotlight
import CoreTransferable
import Foundation
import Models
import SwiftData

/// The Notes schema is iOS 27-only; the same local identifier and query also
/// back the iOS 18 entity, rather than raising the app's deployment target.
@available(iOS 27, macOS 27, visionOS 27, *)
@AppEntity(schema: .notes.note)
public struct SiriMemoEntity: IndexedEntity, Transferable {
    public static let persistentIdentifier = "SiriMemoEntity"
    public static let defaultQuery = SiriMemoQuery()
    public let id: String
    public var name: AttributedString
    public var content: AttributedString?
    public var attachments: [IntentFile]
    public var isPinned: Bool
    public var creationDate: Date?
    public var modificationDate: Date?
    public var folder: SiriMemoFolderEntity?

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(String(name.characters))")
    }

    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = String(name.characters)
        attributes.textContent = content.map { String($0.characters) }
        return attributes
    }

    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { entity in entity.content.map { String($0.characters) } ?? String(entity.name.characters) }
    }

    public init(_ entity: MemoEntity) {
        id = entity.id
        name = AttributedString(entity.title)
        content = AttributedString(entity.content)
        attachments = entity.attachments
        isPinned = entity.isPinned
        creationDate = entity.createdAt
        modificationDate = entity.updatedAt
        folder = SiriMemoFolderEntity(id: entity.accountKey, name: entity.accountName)
    }
}

@available(iOS 27, macOS 27, visionOS 27, *)
public struct SiriMemoQuery: EntityStringQuery {
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [SiriMemoEntity] {
        try await MemoEntityQuery().entities(for: identifiers).map(SiriMemoEntity.init)
    }
    public func entities(matching string: String) async throws -> [SiriMemoEntity] {
        try await MemoEntityQuery().entities(matching: string).map(SiriMemoEntity.init)
    }
    public func suggestedEntities() async throws -> [SiriMemoEntity] {
        try await entities(matching: "")
    }
}

@available(iOS 27, macOS 27, visionOS 27, *)
@AppIntent(schema: .notes.appendText)
public struct SiriAppendToMemoIntent {
    public static let persistentIdentifier = "SiriAppendToMemoIntent"
    public init() {}
    public var content: AttributedString
    public var target: SiriMemoEntity

    public func perform() async throws -> some ReturnsValue<SiriMemoEntity> {
        .result(value: SiriMemoEntity(try await MemoActions.append(String(content.characters), to: target.id)))
    }
}

@available(iOS 27, macOS 27, visionOS 27, *)
@AppIntent(schema: .notes.createNote)
public struct SiriCreateMemoIntent {
    public static let persistentIdentifier = "SiriCreateMemoIntent"
    public init() {}
    public var name: AttributedString
    public var content: AttributedString?
    public var attachments: [IntentFile]
    public var isPinned: Bool
    public var folder: SiriMemoFolderEntity?

    @MainActor
    public func perform() async throws -> some ReturnsValue<SiriMemoEntity> {
        MemoSpotlightIndex.shared.startObserving()
        let context = AppInfo().modelContext
        let manager = AccountManager(modelContext: context)
        let service: any Service
        if let folder {
            guard try MemoEntityStore(context: context).accountNames()[folder.id] != nil,
                  let selectedService = manager.service(for: folder.id) else { throw MemoIntentError.notFound }
            service = selectedService
        } else {
            service = try manager.mustCurrentService
        }
        let title = String(name.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = content.map { String($0.characters) } ?? ""
        let text = [title, body].filter { !$0.isEmpty }.joined(separator: "\n\n")
        guard !text.isEmpty || !attachments.isEmpty else { throw MemoIntentError.emptyContent }
        for attachment in attachments where attachment.data.count > 1_073_741_824 {
            throw MoeMemosError.fileTooLarge(1_073_741_824)
        }
        var resources: [PersistentIdentifier] = []
        for attachment in attachments {
            let resource = try await service.createResource(filename: attachment.filename, data: attachment.data,
                type: attachment.type?.preferredMIMEType ?? "application/octet-stream", memoId: nil)
            resources.append(resource.id)
        }
        let memo = try await service.createMemo(content: text, visibility: nil, resources: resources, tags: nil)
        if isPinned {
            _ = try await service.updateMemo(id: memo.id, content: nil, resources: nil, visibility: nil, tags: nil, pinned: true)
        }
        await MemoSpotlightIndex.shared.flush()
        let id = MemoEntityIdentifier(accountKey: memo.accountKey, persistentID: memo.id).token!
        guard let entity = try MemoEntityStore(context: context).entities(for: [id]).first else { throw MemoIntentError.notFound }
        return .result(value: SiriMemoEntity(entity))
    }
}

@available(iOS 27, macOS 27, visionOS 27, *)
@AppEntity(schema: .notes.account)
public struct SiriMemoAccountEntity {
    public static let persistentIdentifier = "SiriMemoAccountEntity"
    public static let defaultQuery = SiriMemoAccountQuery()
    public let id: String
    public var name: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }
    public init(id: String, name: String) { self.id = id; self.name = name }
}

@available(iOS 27, macOS 27, visionOS 27, *)
public struct SiriMemoAccountQuery: EntityQuery {
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [SiriMemoAccountEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    public func suggestedEntities() async throws -> [SiriMemoAccountEntity] {
        try await MainActor.run {
            try MemoEntityStore(context: AppInfo().modelContext).accountNames()
                .map { SiriMemoAccountEntity(id: $0.key, name: $0.value) }.sorted { $0.id < $1.id }
        }
    }
}

/// Each account is a root collection; Moe Memos doesn't have nested folders.
@available(iOS 27, macOS 27, visionOS 27, *)
@AppEntity(schema: .notes.folder)
public struct SiriMemoFolderEntity {
    public static let persistentIdentifier = "SiriMemoFolderEntity"
    public static let defaultQuery = SiriMemoFolderQuery()
    public let id: String
    public var name: String
    public var parentFolder: SiriMemoFolderEntity? { nil }
    public var account: SiriMemoAccountEntity? { SiriMemoAccountEntity(id: id, name: name) }
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }
    public init(id: String, name: String) { self.id = id; self.name = name }
}

@available(iOS 27, macOS 27, visionOS 27, *)
public struct SiriMemoFolderQuery: EntityStringQuery {
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [SiriMemoFolderEntity] {
        try await SiriMemoAccountQuery().entities(for: identifiers).map { .init(id: $0.id, name: $0.name) }
    }
    public func suggestedEntities() async throws -> [SiriMemoFolderEntity] {
        try await SiriMemoAccountQuery().suggestedEntities().map { .init(id: $0.id, name: $0.name) }
    }
    public func entities(matching string: String) async throws -> [SiriMemoFolderEntity] {
        try await suggestedEntities().filter { string.isEmpty || $0.name.localizedStandardContains(string) }
    }
}

@available(iOS 27, macOS 27, visionOS 27, *)
public struct SiriOpenMemoIntent: OpenIntent {
    public static let persistentIdentifier = "SiriOpenMemoIntent"
    public static let title: LocalizedStringResource = "Open Memo"
    public static let isDiscoverable = false
    @Parameter(title: "Memo") public var target: SiriMemoEntity
    @Dependency private var navigator: MemoNavigator
    public init() {}

    init(target: SiriMemoEntity, navigator: MemoNavigator) {
        self.target = target
        self.navigator = navigator
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        try navigator.openMemo(identifier: target.id)
        return .result()
    }
}
