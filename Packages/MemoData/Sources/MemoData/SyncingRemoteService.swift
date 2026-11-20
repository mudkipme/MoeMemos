//
//  SyncingRemoteService.swift
//
//  Created by Mudkip on 2026/2/4.
//

import Foundation
import OSLog
import SwiftData
import Models

/// Local-first service for remote accounts.
/// - UI talks to this via `Service` using SwiftData `PersistentIdentifier`s.
/// - Sync engine talks to the server via `RemoteService` using server ids (Memo.remoteId / Resource.remoteId).
@MainActor
final class SyncingRemoteService: Service, SyncableService, PendingOperationsService {
    private static let logger = Logger(subsystem: "me.mudkip.MoeMemos", category: "Sync")

    private let remote: RemoteService
    private let store: LocalStore
    private let accountKey: String

    // Serialize all remote operations + sync to avoid conflicting writes.
    private var operationChain: Task<Void, Never>?
    private var stateChangeHandler: (@MainActor () -> Void)?
    private(set) var lastSyncError: Error?

    init(remote: RemoteService, context: ModelContext, accountKey: String) {
        self.remote = remote
        self.store = LocalStore(context: context, accountKey: accountKey)
        self.accountKey = accountKey
    }

    func setStateChangeHandler(_ handler: (@MainActor () -> Void)?) {
        stateChangeHandler = handler
    }

    func pendingChangesCount() -> Int {
        let pendingMemos = store.allMemos(includeDeleted: true).filter { $0.syncState != .synced }.count
        let pendingResources = store.allResources(includeDeleted: true).filter { $0.syncState != .synced }.count
        return pendingMemos + pendingResources
    }

    private func notifyStateChanged() {
        stateChangeHandler?()
    }

    private func recordBackgroundSuccess() {
        lastSyncError = nil
        notifyStateChanged()
    }

    private func recordBackgroundError(_ error: Error, context: String) {
        Self.logger.error("Background \(context, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        lastSyncError = error
        notifyStateChanged()
    }

    private func enqueueOperation(_ operation: @escaping @MainActor () async -> Void) {
        let previous = operationChain
        operationChain = Task { @MainActor in
            _ = await previous?.value
            await operation()
        }
    }

    private func runSerialized<T: Sendable>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            enqueueOperation {
                do {
                    continuation.resume(returning: try await operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Service

    func memoVisibilities() -> [MemoVisibility] {
        remote.memoVisibilities()
    }

    func listMemos() async throws -> [StoredMemo] {
        store.listMemos(rowStatus: .normal)
    }

    func listArchivedMemos() async throws -> [StoredMemo] {
        store.listMemos(rowStatus: .archived)
    }

    func memo(id: PersistentIdentifier) -> StoredMemo? {
        guard let memo = store.fetchMemo(id: id), !memo.softDeleted else {
            return nil
        }
        return memo
    }

    var supportsMemoLocations: Bool { remote.supportsMemoLocations }

    func createMemo(content: String, visibility: MemoVisibility?, resources: [PersistentIdentifier], tags: [String]?, location: MemoLocation? = nil) async throws -> StoredMemo {
        if location != nil && !supportsMemoLocations { throw MoeMemosError.locationUnsupported }
        if let location, !location.isValid { throw MoeMemosError.invalidParams }
        let now = Date()
        let stored = store.createLocalMemo(
            serverId: nil,
            content: content,
            pinned: false,
            rowStatus: .normal,
            visibility: visibility ?? store.fetchUser()?.defaultVisibility ?? .private,
            createdAt: now,
            updatedAt: now,
            softDeleted: false,
            syncState: .pendingCreate,
            lastSyncedAt: nil
        )

        stored.location = location

        for resourceId in resources {
            if let resource = store.fetchResource(id: resourceId) {
                resource.memo = stored
            }
        }

        try store.save()
        notifyStateChanged()

        let memoId = stored.persistentModelID
        let memoTags = tags
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      latest.serverId == nil,
                      latest.softDeleted == false,
                      latest.syncState == .pendingCreate else { return }
                _ = try await self.pushLocalCreate(local: latest, tags: memoTags)
                try self.store.save()
                self.recordBackgroundSuccess()
            } catch {
                self.recordBackgroundError(error, context: "createMemo")
            }
        }

        return stored
    }

    func updateMemo(id: PersistentIdentifier, content: String?, resources: [PersistentIdentifier]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?, location: MemoLocationUpdate? = nil) async throws -> StoredMemo {
        if location != nil && !supportsMemoLocations { throw MoeMemosError.locationUnsupported }
        if let value = location?.location, !value.isValid { throw MoeMemosError.invalidParams }
        guard let stored = store.fetchMemo(id: id) else { throw MoeMemosError.invalidParams }

        if let content { stored.content = content }
        if let visibility { stored.visibility = visibility }
        if let location { stored.location = location.location }
        if let pinned { stored.pinned = pinned }

        if let resources {
            let desired = Set(resources)
            let existing = stored.resources
            for res in existing where !desired.contains(res.persistentModelID) {
                res.memo = nil
            }
            for resourceId in resources {
                if let res = store.fetchResource(id: resourceId) {
                    res.memo = stored
                }
            }
        }

        stored.updatedAt = .now
        stored.syncState = SyncStateTransition.stateAfterUpdate(serverId: stored.serverId)
        try store.save()
        notifyStateChanged()

        let memoId = stored.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      latest.softDeleted == false,
                      latest.syncState != .synced else { return }
                _ = try await self.pushLocalMemo(local: latest, tags: tags)
                try self.store.save()
                self.recordBackgroundSuccess()
            } catch {
                self.recordBackgroundError(error, context: "updateMemo")
            }
        }

        return stored
    }

    func deleteMemo(id: PersistentIdentifier) async throws {
        guard let stored = store.fetchMemo(id: id) else { return }
        stored.softDeleted = true
        stored.updatedAt = .now
        let nextState = SyncStateTransition.stateAfterDelete(serverId: stored.serverId)
        stored.syncState = nextState
        if nextState == .synced {
            stored.lastSyncedAt = .now
        }
        try store.save()
        notifyStateChanged()

        guard nextState == .pendingDelete else { return }

        let memoId = stored.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      latest.softDeleted,
                      latest.syncState == .pendingDelete,
                      let serverId = latest.serverId else { return }
                try await self.deleteMemoIgnoringNotFound(remoteId: serverId)
                latest.syncState = .synced
                latest.lastSyncedAt = .now
                try self.store.save()
                self.recordBackgroundSuccess()
            } catch {
                self.recordBackgroundError(error, context: "deleteMemo")
            }
        }
    }

    func archiveMemo(id: PersistentIdentifier) async throws {
        try changeRowStatus(id: id, targetStatus: .archived)
    }

    func restoreMemo(id: PersistentIdentifier) async throws {
        try changeRowStatus(id: id, targetStatus: .normal)
    }

    private func changeRowStatus(id: PersistentIdentifier, targetStatus: RowStatus) throws {
        guard let stored = store.fetchMemo(id: id) else { return }
        let transition = SyncStateTransition.stateAfterRowStatusChange(serverId: stored.serverId, currentState: stored.syncState)
        let mutationDate = Date()
        stored.rowStatus = targetStatus
        stored.updatedAt = mutationDate
        stored.syncState = transition.nextState
        try store.save()
        notifyStateChanged()

        let memoId = stored.persistentModelID
        let operationName = targetStatus == .archived ? "archiveMemo" : "restoreMemo"
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      !latest.softDeleted,
                      latest.rowStatus == targetStatus,
                      latest.syncState != .synced else { return }

                if latest.serverId == nil || transition.requiresFullPush || latest.updatedAt != mutationDate {
                    _ = try await self.pushLocalMemo(local: latest, tags: nil)
                } else if let serverId = latest.serverId {
                    try await self.pushRowStatus(remoteId: serverId, rowStatus: targetStatus)
                    latest.syncState = .synced
                }
                try self.store.save()
                self.recordBackgroundSuccess()
            } catch {
                self.recordBackgroundError(error, context: operationName)
            }
        }
    }

    func listTags() async throws -> [Tag] {
        let memos = store.listMemos(rowStatus: .normal)
        let tags = Set(memos.flatMap { MemoTagExtractor.extract(from: $0.content) })
        return tags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { Tag(name: $0) }
    }

    func listResources() async throws -> [StoredResource] {
        store.listResources()
    }

    func resource(id: PersistentIdentifier) -> StoredResource? {
        store.fetchResource(id: id)
    }

    func createResource(filename: String, data: Data, type: String, memoId: PersistentIdentifier?) async throws -> StoredResource {
        let localFileURL = try ResourceFileStore.store(
            data: data,
            filename: filename,
            mimeType: type,
            accountKey: accountKey,
            resourceId: UUID().uuidString
        )
        let createdAt = Date()

        let stored = store.createLocalResource(
            serverId: nil,
            filename: filename,
            size: data.count,
            mimeType: type,
            createdAt: createdAt,
            updatedAt: createdAt,
            urlString: localFileURL.absoluteString,
            localPath: localFileURL.path,
            memo: memoId.flatMap { store.fetchMemo(id: $0) },
            softDeleted: false,
            syncState: .pendingCreate,
            lastSyncedAt: nil
        )

        try store.save()
        notifyStateChanged()

        let resourceId = stored.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchResource(id: resourceId),
                      latest.serverId == nil,
                      latest.softDeleted == false,
                      latest.syncState == .pendingCreate else { return }
                _ = try await self.pushLocalResourceCreate(local: latest)
                try self.store.save()

                if let memo = latest.memo,
                   memo.serverId != nil,
                   memo.syncState == .synced {
                    memo.syncState = .pendingUpdate
                    memo.updatedAt = .now
                    try? self.store.save()
                }
                self.recordBackgroundSuccess()
            } catch {
                self.recordBackgroundError(error, context: "createResource")
            }
        }

        return stored
    }

    func deleteResource(id: PersistentIdentifier) async throws {
        guard let resource = store.fetchResource(id: id) else { return }
        resource.softDeleted = true
        resource.updatedAt = .now

        let nextState = SyncStateTransition.stateAfterDelete(serverId: resource.serverId)
        resource.syncState = nextState
        if nextState == .synced {
            resource.lastSyncedAt = .now
            ResourceFileStore.deleteFile(atPath: resource.localPath)
        }
        try store.save()
        notifyStateChanged()

        guard nextState == .pendingDelete else { return }

        let resourceId = resource.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchResource(id: resourceId),
                      latest.softDeleted,
                      latest.syncState == .pendingDelete,
                      let serverId = latest.serverId else { return }
                try await self.deleteResourceIgnoringNotFound(remoteId: serverId)
                latest.syncState = .synced
                latest.lastSyncedAt = .now
                ResourceFileStore.deleteFile(atPath: latest.localPath)
                try self.store.save()
                self.recordBackgroundSuccess()
            } catch {
                self.recordBackgroundError(error, context: "deleteResource")
            }
        }
    }

    func getCurrentUser() async throws -> User {
        if let cached = store.fetchUser() {
            return cached
        }
        let snapshot = try await remote.getCurrentUser()
        store.upsertUser(snapshot)
        try? store.save()
        if let cached = store.fetchUser() {
            return cached
        }
        return snapshot.toUserModel()
    }

    func ensureLocalResourceFile(id: PersistentIdentifier) async throws -> URL {
        guard let resource = store.fetchResource(id: id) else {
            throw MoeMemosError.invalidParams
        }
        if let localPath = resource.localPath, FileManager.default.fileExists(atPath: localPath) {
            return URL(fileURLWithPath: localPath)
        }
        if let url = resource.url, url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
            resource.localPath = url.path
            try? store.save()
            return url
        }
        guard let remoteURL = resource.url else {
            throw MoeMemosError.invalidParams
        }

        let downloaded = try await remote.download(url: remoteURL, mimeType: resource.mimeType)
        let storedURL: URL
        if downloaded.isFileURL {
            storedURL = try ResourceFileStore.store(
                fileAt: downloaded,
                filename: resource.filename,
                mimeType: resource.mimeType,
                accountKey: accountKey,
                resourceId: UUID().uuidString
            )
        } else {
            let data = try Data(contentsOf: downloaded)
            storedURL = try ResourceFileStore.store(
                data: data,
                filename: resource.filename,
                mimeType: resource.mimeType,
                accountKey: accountKey,
                resourceId: UUID().uuidString
            )
        }
        resource.localPath = storedURL.path
        if resource.serverId != nil {
            resource.urlString = remoteURL.absoluteString
        } else {
            resource.urlString = storedURL.absoluteString
        }
        try? store.save()
        return storedURL
    }

    // MARK: - SyncableService

    func waitForPendingOperations() async {
        let pending = operationChain
        _ = await pending?.value
    }

    func sync() async throws {
        try await runSerialized { [self] in
            var firstItemError: Error?

            @MainActor
            func handleItemError(_ error: Error, context: String) throws {
                Self.logger.error("Sync \(context, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                if SyncErrorClassifier.shouldAbortSync(error) {
                    try? self.store.save()
                    self.lastSyncError = error
                    self.notifyStateChanged()
                    throw error
                }
                if firstItemError == nil {
                    firstItemError = error
                }
            }

            let remoteMemos: [Memo]
            do {
                try await self.syncCurrentUserStrict()
                let remoteNormal = try await self.remote.listMemos()
                let remoteArchived = try await self.remote.listArchivedMemos()
                remoteMemos = remoteNormal + remoteArchived
            } catch {
                Self.logger.error("Sync fetch failed: \(error.localizedDescription, privacy: .public)")
                self.lastSyncError = error
                self.notifyStateChanged()
                throw error
            }

            let syncedAt = Date()

            let localMemos = self.store.allMemos(includeDeleted: true)
            var localByServerId: [String: StoredMemo] = [:]
            for memo in localMemos {
                if let serverId = memo.serverId {
                    localByServerId[serverId] = memo
                }
            }

            var remoteById: [String: Memo] = [:]
            for memo in remoteMemos {
                if let id = memo.remoteId {
                    remoteById[id] = memo
                }
            }

            for remoteMemo in remoteMemos {
                guard let serverId = remoteMemo.remoteId else { continue }
                if let local = localByServerId[serverId] {
                    if local.softDeleted {
                        if let error = await self.resolveLocalDeleted(local: local, remote: remoteMemo, syncedAt: syncedAt) {
                            try handleItemError(error, context: "resolveLocalDeleted")
                        }
                    } else {
                        if let error = await self.resolveBothPresent(local: local, remote: remoteMemo, syncedAt: syncedAt) {
                            try handleItemError(error, context: "resolveBothPresent")
                        }
                    }
                } else {
                    self.applyRemoteMemo(remoteMemo, syncedAt: syncedAt)
                }
            }

            for local in localMemos {
                if let serverId = local.serverId {
                    if remoteById[serverId] == nil {
                        if let error = await self.resolveServerDeleted(local: local, syncedAt: syncedAt) {
                            try handleItemError(error, context: "resolveServerDeleted")
                        }
                    }
                } else {
                    if local.softDeleted {
                        local.syncState = .synced
                        local.lastSyncedAt = syncedAt
                    } else {
                        do {
                            let pushed = try await self.pushLocalMemo(local: local, tags: nil)
                            self.applyRemoteMemo(pushed, syncedAt: syncedAt)
                        } catch {
                            if local.serverId == nil {
                                local.syncState = .pendingCreate
                            } else {
                                local.syncState = .pendingUpdate
                            }
                            try handleItemError(error, context: "pushPendingCreate")
                        }
                    }
                }
            }

            let pendingResourceDeletes = self.store.allResources(includeDeleted: true).filter { $0.syncState == .pendingDelete }
            for resource in pendingResourceDeletes {
                do {
                    guard let serverId = resource.serverId else {
                        resource.syncState = .synced
                        resource.lastSyncedAt = syncedAt
                        ResourceFileStore.deleteFile(atPath: resource.localPath)
                        continue
                    }
                    try await self.deleteResourceIgnoringNotFound(remoteId: serverId)
                    resource.syncState = .synced
                    resource.lastSyncedAt = syncedAt
                    ResourceFileStore.deleteFile(atPath: resource.localPath)
                } catch {
                    try handleItemError(error, context: "deletePendingResource")
                }
            }

            try self.store.save()
            self.lastSyncError = firstItemError
            self.notifyStateChanged()
            if let firstItemError {
                throw firstItemError
            }
        }
    }

    // MARK: - Sync Helpers

    private func syncCurrentUserStrict() async throws {
        let snapshot = try await remote.getCurrentUser()
        store.upsertUser(snapshot)
        try store.save()
    }

    private func resolveLocalDeleted(local: StoredMemo, remote: Memo, syncedAt: Date) async -> Error? {
        let remoteChanged = hasRemoteChanged(local: local, remote: remote)
        let remoteMatchesDeletedLocal = memoEquivalent(memoFromStored(local), remote)

        switch SyncStateTransition.resolveLocalDeleted(
            syncState: local.syncState,
            remoteChanged: remoteChanged,
            remoteMatchesLocal: remoteMatchesDeletedLocal
        ) {
        case .restoreFromRemote:
            applyRemoteMemo(remote, syncedAt: syncedAt)
            return nil
        case .deleteOnServer:
            do {
                if let remoteId = remote.remoteId {
                    try await deleteMemoIgnoringNotFound(remoteId: remoteId)
                }
                local.syncState = .synced
                // Track the last remote updatedAt we observed, not the local sync time.
                local.lastSyncedAt = remote.updatedAt
                return nil
            } catch {
                local.syncState = .pendingDelete
                return error
            }
        }
    }

    private func resolveBothPresent(local: StoredMemo, remote: Memo, syncedAt: Date) async -> Error? {
        let localMemo = memoFromStored(local)
        let localChanged = local.syncState != .synced
        let remoteChanged = hasRemoteChanged(local: local, remote: remote)
        let equivalent = memoEquivalent(localMemo, remote)

        switch SyncStateTransition.resolveBothPresent(
            localChanged: localChanged,
            remoteChanged: remoteChanged,
            equivalent: equivalent
        ) {
        case .markSynced:
            local.syncState = .synced
            local.lastSyncedAt = remote.updatedAt
            return nil
        case .applyRemote:
            applyRemoteMemo(remote, syncedAt: syncedAt)
            return nil
        case .pushLocal:
            do {
                let updated = try await pushLocalMemo(local: local, tags: nil, remoteBaseline: remote)
                applyRemoteMemo(updated, syncedAt: syncedAt)
                try store.save()
                return nil
            } catch {
                local.syncState = local.serverId == nil ? .pendingCreate : .pendingUpdate
                return error
            }
        case .duplicateLocalAndApplyRemote:
            // Both changed: preserve local edits as a new memo and apply remote version.
            do {
                _ = try await createDuplicateFromLocal(local, syncedAt: syncedAt)
            } catch {
                Self.logger.error("Failed to duplicate conflicting local memo: \(error.localizedDescription, privacy: .public)")
            }
            applyRemoteMemo(remote, syncedAt: syncedAt)
            return nil
        }
    }

    private func hasRemoteChanged(local: StoredMemo, remote: Memo) -> Bool {
        guard let lastSyncedAt = local.lastSyncedAt else {
            return true
        }
        // Compare equality instead of ordering to avoid clock-skew assumptions.
        return remote.updatedAt != lastSyncedAt
    }

    private func resolveServerDeleted(local: StoredMemo, syncedAt: Date) async -> Error? {
        switch SyncStateTransition.resolveServerDeleted(
            localSoftDeleted: local.softDeleted,
            localChanged: local.syncState != .synced
        ) {
        case .markLocalDeletedSynced:
            local.syncState = .synced
            return nil
        case .recreateOnServer:
            local.serverId = nil
            local.syncState = .pendingCreate
            local.lastSyncedAt = nil
            do {
                let pushed = try await pushLocalMemo(local: local, tags: nil)
                applyRemoteMemo(pushed, syncedAt: syncedAt)
                try store.save()
                return nil
            } catch {
                local.syncState = local.serverId == nil ? .pendingCreate : .pendingUpdate
                return error
            }
        case .softDeleteLocal:
            local.softDeleted = true
            local.syncState = .synced
            return nil
        }
    }

    private func memoFromStored(_ stored: StoredMemo) -> Memo {
        let resources = stored.resources
            .filter { $0.accountKey == accountKey && !$0.softDeleted }
            .compactMap { $0.toResource() }
        return Memo(
            user: nil,
            content: stored.content,
            pinned: stored.pinned,
            rowStatus: stored.rowStatus,
            visibility: stored.visibility,
            resources: resources,
            createdAt: stored.createdAt,
            updatedAt: stored.updatedAt,
            remoteId: stored.serverId,
            location: stored.location
        )
    }

    private func memoEquivalent(_ local: Memo, _ remote: Memo) -> Bool {
        guard local.rowStatus == remote.rowStatus else { return false }
        return memoFieldsExcludingRowStatusEquivalent(local, remote)
    }

    private func memoFieldsExcludingRowStatusEquivalent(_ local: Memo, _ remote: Memo) -> Bool {
        guard local.location == remote.location else { return false }
        guard local.content == remote.content else { return false }
        guard local.pinned == remote.pinned else { return false }
        guard local.visibility == remote.visibility else { return false }
        return resourceSignature(local.resources) == resourceSignature(remote.resources)
    }

    private func resourceSignature(_ resources: [Resource]) -> [String] {
        resources.map { resource in
            if let remoteId = resource.remoteId {
                return remoteId
            }
            return resource.url.absoluteString
        }
        .sorted()
    }

    private func applyRemoteMemo(_ memo: Memo, syncedAt: Date) {
        guard let serverId = memo.remoteId else { return }
        let stored = store.upsertMemo(memo, syncState: .synced)
        stored.serverId = serverId
        stored.softDeleted = false
        stored.lastSyncedAt = memo.updatedAt
        store.reconcileResources(memo.resources, to: stored, preserveLocalOnly: true)
    }

    private func createDuplicateFromLocal(_ local: StoredMemo, syncedAt: Date) async throws -> StoredMemo {
        let duplicated = store.createLocalMemo(
            serverId: nil,
            content: local.content,
            pinned: local.pinned,
            rowStatus: local.rowStatus,
            visibility: local.visibility,
            createdAt: local.createdAt,
            updatedAt: local.updatedAt,
            softDeleted: false,
            syncState: .pendingCreate,
            lastSyncedAt: nil
        )

        duplicated.location = local.location

        let resources = local.resources
            .filter { $0.accountKey == accountKey && !$0.softDeleted }
        for res in resources {
            _ = store.createLocalResource(
                serverId: res.serverId,
                filename: res.filename,
                size: res.size,
                mimeType: res.mimeType,
                createdAt: res.createdAt,
                updatedAt: res.updatedAt,
                urlString: res.urlString,
                localPath: res.localPath,
                memo: duplicated,
                softDeleted: false,
                syncState: res.serverId == nil ? .pendingCreate : .synced,
                lastSyncedAt: res.lastSyncedAt
            )
        }
        try store.save()

        // Kick off a server create in the background; it will upload resources as needed.
        let memoId = duplicated.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      latest.serverId == nil,
                      latest.softDeleted == false,
                      latest.syncState == .pendingCreate else { return }
                _ = try await self.pushLocalCreate(local: latest, tags: nil)
                try self.store.save()
                self.recordBackgroundSuccess()
            } catch {
                self.recordBackgroundError(error, context: "pushConflictedDuplicate")
            }
        }

        return duplicated
    }

    // MARK: - Push Helpers

    private func pushLocalMemo(local: StoredMemo, tags: [String]?, remoteBaseline: Memo? = nil) async throws -> Memo {
        if local.serverId == nil || local.syncState == .pendingCreate {
            return try await pushLocalCreate(local: local, tags: tags)
        }
        return try await pushLocalUpdate(local: local, tags: tags, remoteBaseline: remoteBaseline)
    }

    private func pushLocalCreate(local: StoredMemo, tags: [String]?) async throws -> Memo {
        let desiredPinned = local.pinned
        let desiredRowStatus = local.rowStatus
        let desiredUpdatedAt = local.updatedAt

        let resources = try await ensureUploadedResources(for: local, memoServerId: nil)
        let memo = memoFromStored(local)
        let created = try await remote.createMemo(
            content: memo.content,
            visibility: memo.visibility,
            resources: resources,
            tags: tags,
            createdAt: local.createdAt,
            updatedAt: local.updatedAt,
            location: memo.location
        )
        store.reconcileServerCreatedMemo(
            local: local,
            created: created,
            syncedAt: created.updatedAt
        )
        if desiredPinned != created.pinned || desiredRowStatus != created.rowStatus {
            local.pinned = desiredPinned
            local.rowStatus = desiredRowStatus
            local.syncState = .pendingUpdate
        }
        try store.save()

        var finalMemo = created
        if desiredPinned != finalMemo.pinned, let serverId = local.serverId {
            let updated = try await remote.updateMemo(
                remoteId: serverId,
                content: nil,
                resources: nil,
                visibility: nil,
                tags: nil,
                pinned: desiredPinned,
                updatedAt: desiredUpdatedAt,
                location: nil
            )
            finalMemo = updated
            applyRemoteMemo(updated, syncedAt: updated.updatedAt)
            if desiredRowStatus != finalMemo.rowStatus {
                local.rowStatus = desiredRowStatus
                local.syncState = .pendingUpdate
            }
            try store.save()
        }

        if desiredRowStatus != finalMemo.rowStatus, let serverId = local.serverId {
            try await pushRowStatus(remoteId: serverId, rowStatus: desiredRowStatus)
            finalMemo.rowStatus = desiredRowStatus
            local.rowStatus = desiredRowStatus
            local.syncState = .synced
            try store.save()
        }

        return finalMemo
    }

    private func pushLocalUpdate(local: StoredMemo, tags: [String]?, remoteBaseline: Memo? = nil) async throws -> Memo {
        guard let serverId = local.serverId else { throw MoeMemosError.invalidParams }
        let desiredRowStatus = local.rowStatus

        let hasUnuploadedResources = local.resources.contains {
            $0.accountKey == accountKey && !$0.softDeleted && $0.serverId == nil && $0.syncState != .pendingDelete
        }
        if let remoteBaseline,
           !hasUnuploadedResources,
           memoFieldsExcludingRowStatusEquivalent(memoFromStored(local), remoteBaseline) {
            if desiredRowStatus != remoteBaseline.rowStatus {
                try await pushRowStatus(remoteId: serverId, rowStatus: desiredRowStatus)
            }
            var updated = remoteBaseline
            updated.rowStatus = desiredRowStatus
            local.rowStatus = desiredRowStatus
            local.syncState = .synced
            local.lastSyncedAt = remoteBaseline.updatedAt
            return updated
        }

        let resources = try await ensureUploadedResources(for: local, memoServerId: serverId)
        let memo = memoFromStored(local)
        var updated = try await remote.updateMemo(
            remoteId: serverId,
            content: memo.content,
            resources: resources,
            visibility: memo.visibility,
            tags: tags,
            pinned: memo.pinned,
            updatedAt: local.updatedAt,
            location: supportsMemoLocations ? memo.location.map(MemoLocationUpdate.set) ?? .remove : nil
        )
        applyRemoteMemo(updated, syncedAt: updated.updatedAt)

        if updated.rowStatus != desiredRowStatus {
            local.rowStatus = desiredRowStatus
            local.syncState = .pendingUpdate
            try store.save()

            try await pushRowStatus(remoteId: serverId, rowStatus: desiredRowStatus)
            updated.rowStatus = desiredRowStatus
            local.rowStatus = desiredRowStatus
            local.syncState = .synced
        }

        return updated
    }

    private func pushRowStatus(remoteId: String, rowStatus: RowStatus) async throws {
        switch rowStatus {
        case .archived:
            try await remote.archiveMemo(remoteId: remoteId)
        case .normal:
            try await remote.restoreMemo(remoteId: remoteId)
        }
    }

    private func deleteMemoIgnoringNotFound(remoteId: String) async throws {
        do {
            try await remote.deleteMemo(remoteId: remoteId)
        } catch {
            if SyncErrorClassifier.isAlreadyDeletedOnServer(error) {
                return
            }
            throw error
        }
    }

    private func deleteResourceIgnoringNotFound(remoteId: String) async throws {
        do {
            try await remote.deleteResource(remoteId: remoteId)
        } catch {
            if SyncErrorClassifier.isAlreadyDeletedOnServer(error) {
                return
            }
            throw error
        }
    }

    private func ensureUploadedResources(for local: StoredMemo, memoServerId: String?) async throws -> [Resource] {
        let storedResources = local.resources
            .filter { $0.accountKey == accountKey && !$0.softDeleted }

        for res in storedResources where res.serverId == nil && res.syncState != .pendingDelete {
            _ = try await pushLocalResourceCreate(local: res, memoServerId: memoServerId)
        }

        return local.resources
            .filter { $0.accountKey == accountKey && !$0.softDeleted }
            .compactMap { $0.toResource() }
            .filter { $0.remoteId != nil }
    }

    private func pushLocalResourceCreate(local: StoredResource, memoServerId: String? = nil) async throws -> Resource {
        if let _ = local.serverId, let resource = local.toResource() {
            return resource
        }
        guard let data = try loadResourceData(stored: local) else {
            throw MoeMemosError.invalidParams
        }

        let remoteResource = try await remote.createResource(
            filename: local.filename,
            data: data,
            type: local.mimeType,
            memoRemoteId: memoServerId
        )
        local.serverId = remoteResource.remoteId
        local.urlString = remoteResource.url.absoluteString
        local.syncState = .synced
        local.lastSyncedAt = remoteResource.updatedAt
        return remoteResource
    }

    private func loadResourceData(stored: StoredResource) throws -> Data? {
        if let localPath = stored.localPath, FileManager.default.fileExists(atPath: localPath) {
            return try Data(contentsOf: URL(fileURLWithPath: localPath))
        }
        if let url = stored.url, url.isFileURL {
            return try Data(contentsOf: url)
        }
        return nil
    }
}
