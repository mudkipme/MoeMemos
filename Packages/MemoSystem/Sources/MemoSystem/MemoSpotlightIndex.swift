import MemoData
import AppIntents
import CoreSpotlight
import Foundation
import Models
import OSLog
import SwiftData

protocol MemoSearchIndexClient: Sendable {
    func index(_ entities: [MemoEntity]) async throws
    func remove(_ identifiers: [String]) async throws
    func removeAll() async throws
}

// App Intents association can wait on a system service. Never perform that
// work on the main actor, including the synchronous fallback on older OSes.
private actor SystemMemoSearchIndex: MemoSearchIndexClient {
    let index = CSSearchableIndex(name: "MoeMemos.memos", protectionClass: .complete)
    private let delegate = MemoSearchIndexDelegate()

    init() {
        index.indexDelegate = delegate
    }

    func index(_ entities: [MemoEntity]) async throws {
        var items: [CSSearchableItem] = []
        items.reserveCapacity(entities.count)
        for entity in entities {
            let item = CSSearchableItem(uniqueIdentifier: entity.id, domainIdentifier: entity.accountKey, attributeSet: entity.attributeSet)
            item.expirationDate = .distantFuture
            if #available(iOS 27, macOS 27, visionOS 27, *) {
                await item.associateAppEntity(SiriMemoEntity(entity))
            } else {
                item.associateAppEntity(entity)
            }
            items.append(item)
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
    public static let shared = MemoSpotlightIndex(
        journal: MemoIndexJournal.live(), retainsChangesForApp: Bundle.main.bundleURL.pathExtension == "appex"
    )
    private let client: any MemoSearchIndexClient
    private let journal: MemoIndexJournal?
    private let retainsChangesForApp: Bool
    private var initialized = false
    private var sequence = 0
    private var completedSequence = 0
    private struct Waiter {
        let sequence: Int
        let continuation: CheckedContinuation<Void, Never>
        let timer: Task<Void, Never>
    }
    private var waiters: [UUID: Waiter] = [:]
    private var pending: Task<Void, Never>?
    private var container: ModelContainer?
    private let indexesInMemoryStores: Bool
    private let accountAvailable: (String) -> Bool
    private static let logger = Logger(subsystem: "me.mudkip.MoeMemos", category: "Spotlight")

    init(client: any MemoSearchIndexClient = SystemMemoSearchIndex(), indexesInMemoryStores: Bool = false,
         journal: MemoIndexJournal? = nil, retainsChangesForApp: Bool = false,
         accountAvailable: @escaping (String) -> Bool = { Account.retrieve(accountKey: $0) != nil }) {
        self.client = client
        self.journal = journal
        self.retainsChangesForApp = retainsChangesForApp
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
        guard !identifiers.isEmpty, accepts(container) else { return }
        self.container = container
        let entry = record(identifiers: identifiers)
        enqueue {
            try await self.apply(identifiers: identifiers, container: container)
            if let entry { try self.complete([entry]) }
        }
    }

    /// Normal activation only replays changed IDs. The first run migrates the
    /// existing index once; later full repairs are requested explicitly by Spotlight.
    public func synchronize(container: ModelContainer) async {
        guard accepts(container) else { return }
        self.container = container
        enqueue {
            let entries = try self.journal?.pending() ?? []
            if !(self.journal?.isInitialized ?? self.initialized) || entries.contains(where: { $0.identifiers == nil }) {
                try await self.replaceIndex(container: container)
            } else {
                let identifiers = entries.reduce(into: Set<String>()) { $0.formUnion($1.identifiers ?? []) }
                try await self.apply(identifiers: identifiers, container: container)
            }
            try self.complete(entries)
        }
        await flush()
    }

    public func rebuild(container: ModelContainer) async {
        guard accepts(container) else { return }
        self.container = container
        let entry = record(identifiers: nil)
        enqueue {
            try await self.replaceIndex(container: container)
            if let entry { try self.complete([entry]) }
        }
        await flush()
    }

    /// Short-lived hosts give Spotlight a chance to finish, but a stalled system
    /// service must never prevent reporting an already committed user action.
    public func flush() async {
        await flush(timeout: .seconds(1))
    }

    func flush(timeout: Duration) async {
        let target = sequence
        guard completedSequence < target, !Task.isCancelled else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(); return }
                let timer = Task { @MainActor in
                    do { try await Task.sleep(for: timeout) }
                    catch { return }
                    self.finishWaiter(id)
                }
                waiters[id] = Waiter(sequence: target, continuation: continuation, timer: timer)
            }
        } onCancel: {
            Task { @MainActor in self.finishWaiter(id) }
        }
    }

    fileprivate func reindexRequested(identifiers: [String]?) async {
        guard let container else {
            _ = record(identifiers: identifiers.map(Set.init))
            return
        }
        if let identifiers {
            update(identifiers: Set(identifiers), container: container)
            await flush()
        } else {
            await rebuild(container: container)
        }
    }

    private func accepts(_ container: ModelContainer) -> Bool {
        indexesInMemoryStores || !container.configurations.allSatisfy(\.isStoredInMemoryOnly)
    }

    private func complete(_ entries: [MemoIndexJournal.Entry]) throws {
        // An extension can index concurrently with an app repair. Keep its
        // records for the app to replay, even if its own indexing succeeded.
        guard !retainsChangesForApp else { return }
        try journal?.complete(entries)
    }

    private func record(identifiers: Set<String>?) -> MemoIndexJournal.Entry? {
        do { return try journal?.append(identifiers: identifiers) }
        catch {
            journal?.invalidate()
            initialized = false
            Self.logger.error("Could not queue index changes; a full repair is needed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func apply(identifiers: Set<String>, container: ModelContainer) async throws {
        guard !identifiers.isEmpty else { return }
        let store = MemoEntityStore(context: ModelContext(container), accountAvailable: accountAvailable)
        let entities = try store.entities(for: Array(identifiers))
        let removed = identifiers.subtracting(entities.map(\.id))
        if !removed.isEmpty { try await client.remove(Array(removed)) }
        if !entities.isEmpty { try await client.index(entities) }
    }

    private func replaceIndex(container: ModelContainer) async throws {
        let entities = try MemoEntityStore(context: ModelContext(container), accountAvailable: accountAvailable).allEntities()
        try await client.removeAll()
        if !entities.isEmpty { try await client.index(entities) }
        try journal?.markInitialized()
        initialized = true
    }

    private func finishWaiter(_ id: UUID) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        waiter.timer.cancel()
        waiter.continuation.resume()
    }

    private func enqueue(_ operation: @escaping @MainActor () async throws -> Void) {
        let previous = pending
        sequence += 1
        let current = sequence
        pending = Task { @MainActor in
            await previous?.value
            do { try await operation() }
            catch { Self.logger.error("Memo indexing failed; will retry on activation: \(error.localizedDescription, privacy: .public)") }
            self.completedSequence = current
            for id in self.waiters.keys.filter({ self.waiters[$0]!.sequence <= current }) {
                self.finishWaiter(id)
            }
        }
    }
}
