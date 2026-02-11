//
//  SyncingRemoteService.swift
//
//  Created by Mudkip on 2026/2/4.
//

import Foundation
import SwiftData
import Models

/// Local-first service for remote accounts.
/// - UI talks to this via `Service` using SwiftData `PersistentIdentifier`s.
/// - Sync engine talks to the server via `RemoteService` using server ids (Memo.remoteId / Resource.remoteId).
@MainActor
final class SyncingRemoteService: Service, SyncableService {
    private let remote: RemoteService
    private let store: LocalStore
    private let accountKey: String

    // Serialize all remote operations + sync to avoid conflicting writes.
    private var operationChain: Task<Void, Never>?

    init(remote: RemoteService, context: ModelContext, accountKey: String) {
        self.remote = remote
        self.store = LocalStore(context: context, accountKey: accountKey)
        self.accountKey = accountKey
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
        store.fetchMemo(id: id)
    }

    func createMemo(content: String, visibility: MemoVisibility?, resources: [PersistentIdentifier], tags: [String]?) async throws -> StoredMemo {
        let now = Date()
        let stored = store.createLocalMemo(
            serverId: nil,
            content: content,
            pinned: false,
            rowStatus: .normal,
            visibility: visibility ?? .private,
            createdAt: now,
            updatedAt: now,
            softDeleted: false,
            syncState: .pendingCreate,
            lastSyncedAt: nil
        )

        for resourceId in resources {
            if let resource = store.fetchResource(id: resourceId) {
                resource.memo = stored
            }
        }

        try store.save()

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
            } catch {
                return
            }
        }

        return stored
    }

    func updateMemo(id: PersistentIdentifier, content: String?, resources: [PersistentIdentifier]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> StoredMemo {
        guard let stored = store.fetchMemo(id: id) else { throw MoeMemosError.invalidParams }

        if let content { stored.content = content }
        if let visibility { stored.visibility = visibility }
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
        if stored.serverId == nil {
            stored.syncState = .pendingCreate
        } else if stored.syncState == .synced {
            stored.syncState = .pendingUpdate
        }
        try store.save()

        let memoId = stored.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      latest.softDeleted == false,
                      latest.syncState != .synced else { return }
                _ = try await self.pushLocalMemo(local: latest, tags: tags)
                try self.store.save()
            } catch {
                return
            }
        }

        return stored
    }

    func deleteMemo(id: PersistentIdentifier) async throws {
        guard let stored = store.fetchMemo(id: id) else { return }
        stored.softDeleted = true
        stored.updatedAt = .now
        if stored.serverId != nil, stored.syncState == .synced {
            stored.syncState = .pendingDelete
        } else if stored.serverId == nil {
            stored.syncState = .synced
            stored.lastSyncedAt = .now
        }
        try store.save()

        let memoId = stored.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      latest.softDeleted,
                      latest.syncState == .pendingDelete,
                      let serverId = latest.serverId else { return }
                try await self.remote.deleteMemo(remoteId: serverId)
                latest.syncState = .synced
                try self.store.save()
            } catch {
                return
            }
        }
    }

    func archiveMemo(id: PersistentIdentifier) async throws {
        guard let stored = store.fetchMemo(id: id) else { return }
        stored.rowStatus = .archived
        stored.updatedAt = .now
        if stored.serverId == nil {
            stored.syncState = .pendingCreate
        } else if stored.syncState == .synced {
            stored.syncState = .pendingUpdate
        }
        try store.save()

        let memoId = stored.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      latest.rowStatus == .archived,
                      let serverId = latest.serverId else { return }
                try await self.remote.archiveMemo(remoteId: serverId)
                latest.syncState = .synced
                try self.store.save()
            } catch {
                return
            }
        }
    }

    func restoreMemo(id: PersistentIdentifier) async throws {
        guard let stored = store.fetchMemo(id: id) else { return }
        stored.rowStatus = .normal
        stored.updatedAt = .now
        if stored.serverId == nil {
            stored.syncState = .pendingCreate
        } else if stored.syncState == .synced {
            stored.syncState = .pendingUpdate
        }
        try store.save()

        let memoId = stored.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchMemo(id: memoId),
                      latest.rowStatus == .normal,
                      let serverId = latest.serverId else { return }
                try await self.remote.restoreMemo(remoteId: serverId)
                latest.syncState = .synced
                try self.store.save()
            } catch {
                return
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
            } catch {
                return
            }
        }

        return stored
    }

    func deleteResource(id: PersistentIdentifier) async throws {
        guard let resource = store.fetchResource(id: id) else { return }
        resource.softDeleted = true
        resource.updatedAt = .now

        if resource.serverId != nil, resource.syncState == .synced {
            resource.syncState = .pendingDelete
        } else {
            resource.syncState = .synced
            resource.lastSyncedAt = .now
            ResourceFileStore.deleteFile(atPath: resource.localPath)
        }
        try store.save()

        let resourceId = resource.persistentModelID
        enqueueOperation { [weak self] in
            guard let self else { return }
            do {
                guard let latest = self.store.fetchResource(id: resourceId),
                      latest.softDeleted,
                      latest.syncState == .pendingDelete,
                      let serverId = latest.serverId else { return }
                try await self.remote.deleteResource(remoteId: serverId)
                latest.syncState = .synced
                latest.lastSyncedAt = .now
                ResourceFileStore.deleteFile(atPath: latest.localPath)
                try self.store.save()
            } catch {
                return
            }
        }
    }

    func getCurrentUser() async throws -> User {
        if let cached = store.fetchUser() {
            return cached
        }
        let user = try await remote.getCurrentUser()
        store.upsertUser(user)
        try? store.save()
        return user
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

    func sync() async throws {
        try await runSerialized { [self] in
            try await self.syncCurrentUserStrict()

            let remoteNormal = try await self.remote.listMemos()
            let remoteArchived = try await self.remote.listArchivedMemos()
            let remoteMemos = remoteNormal + remoteArchived
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
                        if local.syncState == .pendingDelete {
                            try await self.resolveLocalDeleted(local: local, remote: remoteMemo, syncedAt: syncedAt)
                        } else {
                            // Deleted rows not in `pendingDelete` were not explicitly requested by the user.
                            // Never treat them as authority to delete server data.
                            self.applyRemoteMemo(remoteMemo, syncedAt: syncedAt)
                        }
                    } else {
                        try await self.resolveBothPresent(local: local, remote: remoteMemo, syncedAt: syncedAt)
                    }
                } else {
                    self.applyRemoteMemo(remoteMemo, syncedAt: syncedAt)
                }
            }

            for local in localMemos {
                if let serverId = local.serverId {
                    if remoteById[serverId] == nil {
                        try await self.resolveServerDeleted(local: local, syncedAt: syncedAt)
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
                            local.syncState = .pendingCreate
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
                    try await self.remote.deleteResource(remoteId: serverId)
                    resource.syncState = .synced
                    resource.lastSyncedAt = syncedAt
                    ResourceFileStore.deleteFile(atPath: resource.localPath)
                } catch {
                    continue
                }
            }

            try self.store.save()
        }
    }

    // MARK: - Sync Helpers

    private func syncCurrentUserStrict() async throws {
        let user = try await remote.getCurrentUser()
        store.upsertUser(user)
        try store.save()
    }

    private func resolveLocalDeleted(local: StoredMemo, remote: Memo, syncedAt: Date) async throws {
        guard local.syncState == .pendingDelete else {
            applyRemoteMemo(remote, syncedAt: syncedAt)
            return
        }
        let remoteChanged = hasRemoteChanged(local: local, remote: remote)
        let remoteMatchesDeletedLocal = memoEquivalent(memoFromStored(local), remote)

        if remoteChanged || !remoteMatchesDeletedLocal {
            applyRemoteMemo(remote, syncedAt: syncedAt)
        } else {
            do {
                try await remoteDelete(remoteId: remote.remoteId)
                local.syncState = .synced
                // Track the last remote updatedAt we observed, not the local sync time.
                local.lastSyncedAt = remote.updatedAt
            } catch {
                local.syncState = .pendingDelete
            }
        }
    }

    private func resolveBothPresent(local: StoredMemo, remote: Memo, syncedAt: Date) async throws {
        let localMemo = memoFromStored(local)
        let localChanged = local.syncState != .synced
        let remoteChanged = hasRemoteChanged(local: local, remote: remote)
        let equivalent = memoEquivalent(localMemo, remote)

        if equivalent {
            local.syncState = .synced
            local.lastSyncedAt = remote.updatedAt
            return
        }

        if !localChanged {
            applyRemoteMemo(remote, syncedAt: syncedAt)
            return
        }

        if !remoteChanged {
            do {
                let updated = try await pushLocalMemo(local: local, tags: nil)
                applyRemoteMemo(updated, syncedAt: syncedAt)
                try store.save()
            } catch {
                local.syncState = local.serverId == nil ? .pendingCreate : .pendingUpdate
            }
            return
        }

        // Both changed.
        _ = try? await createDuplicateFromLocal(local, syncedAt: syncedAt)
        applyRemoteMemo(remote, syncedAt: syncedAt)
    }

    private func hasRemoteChanged(local: StoredMemo, remote: Memo) -> Bool {
        guard let lastSyncedAt = local.lastSyncedAt else {
            return true
        }
        // Compare equality instead of ordering to avoid clock-skew assumptions.
        return remote.updatedAt != lastSyncedAt
    }

    private func resolveServerDeleted(local: StoredMemo, syncedAt: Date) async throws {
        if local.softDeleted {
            local.syncState = .synced
            return
        }

        let localChanged = local.syncState != .synced
        if localChanged {
            local.serverId = nil
            local.syncState = .pendingCreate
            local.lastSyncedAt = nil
            do {
                let pushed = try await pushLocalMemo(local: local, tags: nil)
                applyRemoteMemo(pushed, syncedAt: syncedAt)
                try store.save()
            } catch {
                local.syncState = .pendingCreate
            }
        } else {
            local.softDeleted = true
            local.syncState = .synced
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
            remoteId: stored.serverId
        )
    }

    private func memoEquivalent(_ local: Memo, _ remote: Memo) -> Bool {
        guard local.content == remote.content else { return false }
        guard local.pinned == remote.pinned else { return false }
        guard local.rowStatus == remote.rowStatus else { return false }
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
            } catch {
                return
            }
        }

        return duplicated
    }

    // MARK: - Push Helpers

    private func pushLocalMemo(local: StoredMemo, tags: [String]?) async throws -> Memo {
        if local.serverId == nil || local.syncState == .pendingCreate {
            return try await pushLocalCreate(local: local, tags: tags)
        }
        return try await pushLocalUpdate(local: local, tags: tags)
    }

    private func pushLocalCreate(local: StoredMemo, tags: [String]?) async throws -> Memo {
        let resources = try await ensureUploadedResources(for: local, memoServerId: nil)
        let memo = memoFromStored(local)
        let created = try await remote.createMemo(
            content: memo.content,
            visibility: memo.visibility,
            resources: resources,
            tags: tags,
            createdAt: local.createdAt,
            updatedAt: local.updatedAt
        )
        store.reconcileServerCreatedMemo(
            local: local,
            created: created,
            syncedAt: created.updatedAt
        )
        try store.save()
        return created
    }

    private func pushLocalUpdate(local: StoredMemo, tags: [String]?) async throws -> Memo {
        guard let serverId = local.serverId else { throw MoeMemosError.invalidParams }
        let resources = try await ensureUploadedResources(for: local, memoServerId: serverId)

        let memo = memoFromStored(local)
        let updated = try await remote.updateMemo(
            remoteId: serverId,
            content: memo.content,
            resources: resources,
            visibility: memo.visibility,
            tags: tags,
            pinned: memo.pinned,
            updatedAt: local.updatedAt
        )
        applyRemoteMemo(updated, syncedAt: updated.updatedAt)
        return updated
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

    private func remoteDelete(remoteId: String?) async throws {
        guard let remoteId else { return }
        try await remote.deleteMemo(remoteId: remoteId)
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
