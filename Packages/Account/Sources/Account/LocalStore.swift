//
//  LocalStore.swift
//
//
//  Created by Mudkip on 2026/2/3.
//

import Foundation
import SwiftData
import Models

final class LocalStore {
    private let context: ModelContext
    private let accountKey: String

    init(context: ModelContext, accountKey: String) {
        self.context = context
        self.accountKey = accountKey
    }

    func createLocalMemo(
        serverId: String? = nil,
        content: String,
        pinned: Bool,
        rowStatus: RowStatus,
        visibility: MemoVisibility,
        createdAt: Date,
        updatedAt: Date,
        isDeleted: Bool = false,
        syncState: SyncState,
        lastSyncedAt: Date? = nil
    ) -> StoredMemo {
        let stored = StoredMemo(
            accountKey: accountKey,
            serverId: serverId,
            content: content,
            pinned: pinned,
            rowStatus: rowStatus,
            visibility: visibility,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            syncState: syncState,
            lastSyncedAt: lastSyncedAt
        )
        context.insert(stored)
        return stored
    }

    func createLocalResource(
        serverId: String? = nil,
        filename: String,
        size: Int,
        mimeType: String,
        createdAt: Date,
        updatedAt: Date,
        urlString: String,
        localPath: String? = nil,
        memo: StoredMemo? = nil,
        isDeleted: Bool = false,
        syncState: SyncState,
        lastSyncedAt: Date? = nil
    ) -> StoredResource {
        let stored = StoredResource(
            accountKey: accountKey,
            serverId: serverId,
            filename: filename,
            size: size,
            mimeType: mimeType,
            createdAt: createdAt,
            updatedAt: updatedAt,
            urlString: urlString,
            localPath: localPath,
            memo: memo,
            isDeleted: isDeleted,
            syncState: syncState,
            lastSyncedAt: lastSyncedAt
        )
        context.insert(stored)
        return stored
    }

    @MainActor
    func fetchMemo(id: PersistentIdentifier) -> StoredMemo? {
        context.model(for: id) as? StoredMemo
    }

    @MainActor
    func fetchResource(id: PersistentIdentifier) -> StoredResource? {
        context.model(for: id) as? StoredResource
    }

    func listMemos(rowStatus: RowStatus, limit: Int? = nil, offset: Int? = nil) -> [StoredMemo] {
        fetchMemos(rowStatus: rowStatus, limit: limit, offset: offset, pendingOnly: false)
    }

    func listResources() -> [StoredResource] {
        fetchResources()
    }

    func allMemos(includeDeleted: Bool = true) -> [StoredMemo] {
        let predicate = #Predicate<StoredMemo> { memo in
            memo.accountKey == accountKey
        }
        let descriptor = FetchDescriptor<StoredMemo>(predicate: predicate)
        let memos = (try? context.fetch(descriptor)) ?? []
        if includeDeleted {
            return memos
        }
        return memos.filter { !$0.isDeleted }
    }

    func allResources(includeDeleted: Bool = true) -> [StoredResource] {
        let predicate = #Predicate<StoredResource> { resource in
            resource.accountKey == accountKey
        }
        let descriptor = FetchDescriptor<StoredResource>(predicate: predicate)
        let resources = (try? context.fetch(descriptor)) ?? []
        if includeDeleted {
            return resources
        }
        return resources.filter { !$0.isDeleted }
    }

    func fetchUser() -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { user in
                user.accountKey == accountKey
            }
        )
        return try? context.fetch(descriptor).first
    }

    func upsertUser(_ user: User) {
        if let existing = fetchUser() {
            existing.nickname = user.nickname
            existing.avatarData = user.avatarData
            existing.defaultVisibility = user.defaultVisibility
            existing.creationDate = user.creationDate
            existing.email = user.email
            existing.remoteId = user.remoteId
            return
        }

        let stored = User(
            accountKey: accountKey,
            nickname: user.nickname,
            avatarData: user.avatarData,
            defaultVisibility: user.defaultVisibility,
            creationDate: user.creationDate,
            email: user.email,
            remoteId: user.remoteId
        )
        context.insert(stored)
    }

    func fetchMemo(serverId: String) -> StoredMemo? {
        let memoServerId = Optional(serverId)
        let descriptor = FetchDescriptor<StoredMemo>(
            predicate: #Predicate { memo in
                memo.accountKey == accountKey && memo.serverId == memoServerId
            }
        )
        return try? context.fetch(descriptor).first
    }

    func fetchResource(remoteId: String) -> StoredResource? {
        let resourceServerId = Optional(remoteId)
        let descriptor = FetchDescriptor<StoredResource>(
            predicate: #Predicate { resource in
                resource.accountKey == accountKey && resource.serverId == resourceServerId
            }
        )
        return try? context.fetch(descriptor).first
    }

    func fetchResource(urlString: String) -> StoredResource? {
        let descriptor = FetchDescriptor<StoredResource>(
            predicate: #Predicate { resource in
                resource.accountKey == accountKey && resource.urlString == urlString
            }
        )
        return try? context.fetch(descriptor).first
    }

    /// When a locally-created memo is created on the server, reconcile local state so:
    /// - `serverId` is set on the existing local row
    /// - any existing duplicate server-id row (inserted earlier by a pull) is merged and removed
    /// - memo fields are updated to the server result
    ///
    /// - Parameters:
    ///   - mergeAttachments: When `true`, local attachments are reconciled to match `created.resources` exactly
    ///     (this may unlink local-only attachments). Use `false` right after server create when the server
    ///     memo doesn't yet include local attachments.
    ///   - finalSyncState: Usually `.synced` when everything matches server, or `.pendingUpdate` when more
    ///     work (e.g. attachments) still needs to be pushed.
    func reconcileServerCreatedMemo(
        local: StoredMemo,
        created: Memo,
        syncedAt: Date,
        mergeAttachments: Bool = true,
        finalSyncState: SyncState = .synced
    ) {
        guard let serverId = created.remoteId, !serverId.isEmpty else { return }

        // If a server-id row was inserted earlier (e.g. by a sync pull), merge it into the local row.
        if let duplicate = fetchMemo(serverId: serverId), duplicate !== local {
            for resource in duplicate.resources {
                resource.memo = local
            }
            context.delete(duplicate)
            try? context.save()
        }

        local.serverId = serverId
        local.content = created.content
        local.pinned = created.pinned
        local.rowStatus = created.rowStatus
        local.visibility = created.visibility
        local.createdAt = created.createdAt
        local.updatedAt = created.updatedAt
        local.isDeleted = false
        local.syncState = finalSyncState
        local.lastSyncedAt = syncedAt

        if mergeAttachments {
            reconcileResources(created.resources, to: local, preserveLocalOnly: true)
        }
    }

    func upsertMemo(_ memo: Memo, syncState: SyncState, keepSyncState: Bool = false) -> StoredMemo {
        let serverId = memo.remoteId
        let stored: StoredMemo
        if let serverId, let existing = fetchMemo(serverId: serverId) {
            stored = existing
        } else {
            stored = StoredMemo(
                accountKey: accountKey,
                serverId: serverId,
                content: memo.content,
                pinned: memo.pinned,
                rowStatus: memo.rowStatus,
                visibility: memo.visibility,
                createdAt: memo.createdAt,
                updatedAt: memo.updatedAt
            )
        }

        stored.content = memo.content
        stored.pinned = memo.pinned
        stored.rowStatus = memo.rowStatus
        stored.visibility = memo.visibility
        stored.updatedAt = memo.updatedAt
        stored.isDeleted = false
        stored.serverId = serverId ?? stored.serverId
        if !keepSyncState {
            stored.syncState = syncState
            stored.lastSyncedAt = syncState == .synced ? memo.updatedAt : stored.lastSyncedAt
        }

        if stored.modelContext == nil {
            context.insert(stored)
        }

        return stored
    }

    func upsertResource(_ resource: Resource, memo: StoredMemo?, syncState: SyncState, localPath: URL? = nil, keepSyncState: Bool = false) -> StoredResource {
        let stored: StoredResource
        if let serverId = resource.remoteId, let existing = fetchResource(remoteId: serverId) {
            stored = existing
        } else {
            stored = StoredResource(
                accountKey: accountKey,
                serverId: resource.remoteId,
                filename: resource.filename,
                size: resource.size,
                mimeType: resource.mimeType,
                createdAt: resource.createdAt,
                updatedAt: resource.updatedAt,
                urlString: resource.url.absoluteString
            )
        }

        stored.filename = resource.filename
        stored.size = resource.size
        stored.mimeType = resource.mimeType
        stored.updatedAt = resource.updatedAt
        stored.urlString = resource.url.absoluteString
        stored.serverId = resource.remoteId ?? stored.serverId
        if let memo {
            stored.memo = memo
        }
        if let localPath {
            stored.localPath = localPath.path
        }
        stored.isDeleted = false
        if !keepSyncState {
            stored.syncState = syncState
            stored.lastSyncedAt = syncState == .synced ? resource.updatedAt : stored.lastSyncedAt
        }

        if stored.modelContext == nil {
            context.insert(stored)
        }

        return stored
    }

    func reconcileResources(_ resources: [Resource], to memo: StoredMemo, preserveLocalOnly: Bool = false) {
        let desiredRemoteIds = Set(resources.compactMap(\.remoteId))
        let existing = memo.resources
        for stored in existing {
            if let storedRemoteId = stored.serverId, desiredRemoteIds.contains(storedRemoteId) {
                continue
            }
            // Optionally preserve local-only resources (remoteId == nil) when reconciling from server state.
            if preserveLocalOnly, stored.serverId == nil {
                continue
            }
            stored.memo = nil
        }

        for resource in resources {
            guard resource.remoteId != nil else { continue }
            let stored = upsertResource(resource, memo: memo, syncState: .synced, keepSyncState: true)
            stored.memo = memo
            stored.isDeleted = false
        }
    }

    func save() throws {
        try context.save()
    }

    private func fetchMemos(rowStatus: RowStatus, limit: Int? = nil, offset: Int? = nil, pendingOnly: Bool) -> [StoredMemo] {
        let predicate = #Predicate<StoredMemo> { memo in
            memo.accountKey == accountKey && memo.isDeleted == false
        }
        let descriptor = FetchDescriptor<StoredMemo>(predicate: predicate)
        var memos = (try? context.fetch(descriptor)) ?? []
        memos = memos.filter { memo in
            memo.rowStatus == rowStatus && (!pendingOnly || memo.syncState != .synced)
        }
        memos = memos.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.createdAt > rhs.createdAt
        }
        if let offset {
            memos = Array(memos.dropFirst(offset))
        }
        if let limit {
            memos = Array(memos.prefix(limit))
        }
        return memos
    }

    private func fetchResources(includeDeleted: Bool = false, pendingOnly: Bool = false) -> [StoredResource] {
        let predicate = #Predicate<StoredResource> { resource in
            resource.accountKey == accountKey
        }
        let descriptor = FetchDescriptor<StoredResource>(predicate: predicate)
        var resources = (try? context.fetch(descriptor)) ?? []
        resources = resources.filter { resource in
            if !includeDeleted && resource.isDeleted {
                return false
            }
            if pendingOnly && resource.syncState == .synced {
                return false
            }
            return true
        }
        return resources.sorted { $0.createdAt > $1.createdAt }
    }
}
