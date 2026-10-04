import MemoData
import AppIntents
import CoreSpotlight
import Foundation
import Models
import OSLog
import SwiftData

@MainActor
protocol MemoSearchIndexClient {
    func index(_ entities: [MemoEntity]) async throws
    func remove(_ identifiers: [String]) async throws
    func removeAll() async throws
}

@MainActor
private final class SystemMemoSearchIndex: MemoSearchIndexClient {
    let index = CSSearchableIndex(name: "MoeMemos.memos", protectionClass: .complete)
    private let delegate = MemoSearchIndexDelegate()

    init() {
        index.indexDelegate = delegate
    }

    func index(_ entities: [MemoEntity]) async throws {
        let items = entities.map { entity in
            let item = CSSearchableItem(uniqueIdentifier: entity.id, domainIdentifier: entity.accountKey, attributeSet: entity.attributeSet)
            item.expirationDate = .distantFuture
            if #available(iOS 27, macOS 27, visionOS 27, *) {
                item.associateAppEntity(SiriMemoEntity(entity))
            } else {
                item.associateAppEntity(entity)
            }
            return item
        }
        try await index.indexSearchableItems(items)
    }

    func remove(_ identifiers: [String]) async throws {
        try await index.deleteSearchableItems(withIdentifiers: identifiers)
    }

    func removeAll() async throws {
        try await index.deleteAllSearchableItems()
    }
}

private final class MemoSearchIndexDelegate: NSObject, CSSearchableIndexDelegate {
    func searchableIndex(_ searchableIndex: CSSearchableIndex,
                         reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        // Core Spotlight permits asynchronous acknowledgement; its ObjC callback lacks Sendable annotations.
        nonisolated(unsafe) let acknowledge = acknowledgementHandler
        Task { @MainActor in
            await MemoSpotlightIndex.shared.reindexRequested(identifiers: nil)
            acknowledge()
        }
    }

    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String],
                         acknowledgementHandler: @escaping () -> Void) {
        nonisolated(unsafe) let acknowledge = acknowledgementHandler
        Task { @MainActor in
            await MemoSpotlightIndex.shared.reindexRequested(identifiers: identifiers)
            acknowledge()
        }
    }
}

/// Serialize writes, and resolve their content at execution time so queued work
/// cannot resurrect an archived/deleted memo or an account that was removed.
@MainActor
public final class MemoSpotlightIndex: MemoChangeObserver {
    public static let shared = MemoSpotlightIndex()
    private let client: any MemoSearchIndexClient
    private var pending: Task<Void, Never>?
    private var container: ModelContainer?
    private let indexesInMemoryStores: Bool
    private let accountAvailable: (String) -> Bool
    private static let logger = Logger(subsystem: "me.mudkip.MoeMemos", category: "Spotlight")

    init(client: any MemoSearchIndexClient = SystemMemoSearchIndex(), indexesInMemoryStores: Bool = false,
         accountAvailable: @escaping (String) -> Bool = { Account.retrieve(accountKey: $0) != nil }) {
        self.client = client
        self.indexesInMemoryStores = indexesInMemoryStores
        self.accountAvailable = accountAvailable
    }

    /// Called by each host process before it performs mutations.
    public func startObserving() {
        MemoChanges.shared.observer = self
    }

    public func memosDidSave(identifiers: Set<MemoEntityIdentifier>, container: ModelContainer) {
        update(identifiers: Set(identifiers.compactMap(\.token)), container: container)
    }

    func update(identifiers: Set<String>, container: ModelContainer) {
        guard !identifiers.isEmpty, indexesInMemoryStores || !container.configurations.allSatisfy(\.isStoredInMemoryOnly) else { return }
        self.container = container
        enqueue {
            let store = MemoEntityStore(context: ModelContext(container), accountAvailable: self.accountAvailable)
            let entities = try store.entities(for: Array(identifiers))
            let remaining = Set(entities.map(\.id))
            try await self.client.remove(Array(identifiers.subtracting(remaining)))
            try await self.client.index(entities)
        }
    }

    /// Repair missed extension writes or indexing interrupted by process termination.
    public func rebuild(container: ModelContainer) async {
        guard indexesInMemoryStores || !container.configurations.allSatisfy(\.isStoredInMemoryOnly) else { return }
        self.container = container
        enqueue {
            let entities = try MemoEntityStore(context: ModelContext(container), accountAvailable: self.accountAvailable).allEntities()
            try await self.client.removeAll()
            try await self.client.index(entities)
        }
        await flush()
    }

    public func flush() async {
        await pending?.value
    }

    fileprivate func reindexRequested(identifiers: [String]?) async {
        guard let container else { return }
        if let identifiers {
            update(identifiers: Set(identifiers), container: container)
            await flush()
        } else {
            await rebuild(container: container)
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async throws -> Void) {
        let previous = pending
        pending = Task { @MainActor in
            await previous?.value
            do { try await operation() }
            catch { Self.logger.error("Memo indexing failed; will retry on activation: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
