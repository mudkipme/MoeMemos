//
//  LocalService.swift
//
//
//  Created by Mudkip on 2026/2/3.
//

import Foundation
import SwiftData
import Models

final class LocalService: Service {
    private let store: LocalStore
    private let accountKey: String

    init(context: ModelContext, accountKey: String) {
        self.store = LocalStore(context: context, accountKey: accountKey)
        self.accountKey = accountKey
    }

    func memoVisibilities() -> [MemoVisibility] {
        [.private]
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
        let createdAt = Date()
        let memo = Memo(
            content: content,
            pinned: false,
            rowStatus: .normal,
            visibility: visibility ?? .private,
            resources: [],
            createdAt: createdAt,
            updatedAt: createdAt,
            remoteId: nil
        )

        let stored = store.upsertMemo(memo, syncState: .synced)
        stored.lastSyncedAt = .now
        stored.syncState = .synced

        for resourceId in resources {
            if let resource = store.fetchResource(id: resourceId) {
                resource.memo = stored
            }
        }
        try store.save()
        return stored
    }

    func updateMemo(id: PersistentIdentifier, content: String?, resources: [PersistentIdentifier]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> StoredMemo {
        guard let stored = store.fetchMemo(id: id) else {
            throw MoeMemosError.invalidParams
        }

        if let content {
            stored.content = content
        }
        if let visibility {
            stored.visibility = visibility
        }
        if let pinned {
            stored.pinned = pinned
        }
        if let resources {
            let desired = Set(resources)
            let existing = stored.resources
            for res in existing where !desired.contains(res.persistentModelID) {
                res.memo = nil
            }
            for resourceId in resources {
                if let resource = store.fetchResource(id: resourceId) {
                    resource.memo = stored
                }
            }
        }
        stored.updatedAt = .now
        stored.syncState = .synced
        stored.lastSyncedAt = .now

        try store.save()
        return stored
    }

    func deleteMemo(id: PersistentIdentifier) async throws {
        guard let stored = store.fetchMemo(id: id) else { return }
        stored.softDeleted = true
        stored.syncState = .synced
        stored.lastSyncedAt = .now
        try store.save()
    }

    func archiveMemo(id: PersistentIdentifier) async throws {
        guard let stored = store.fetchMemo(id: id) else { return }
        stored.rowStatus = .archived
        stored.updatedAt = .now
        stored.syncState = .synced
        stored.lastSyncedAt = .now
        try store.save()
    }

    func restoreMemo(id: PersistentIdentifier) async throws {
        guard let stored = store.fetchMemo(id: id) else { return }
        stored.rowStatus = .normal
        stored.updatedAt = .now
        stored.syncState = .synced
        stored.lastSyncedAt = .now
        try store.save()
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
        let resourceLocalId = UUID().uuidString
        let fileURL = try ResourceFileStore.store(data: data, filename: filename, mimeType: type, accountKey: accountKey, resourceId: resourceLocalId)
        let createdAt = Date()
        let resource = Resource(
            filename: filename,
            size: data.count,
            mimeType: type,
            createdAt: createdAt,
            updatedAt: createdAt,
            remoteId: nil,
            url: fileURL
        )
        let memo = memoId.flatMap { store.fetchMemo(id: $0) }
        let stored = store.upsertResource(resource, memo: memo, syncState: .synced, localPath: fileURL)
        try store.save()
        return stored
    }

    func deleteResource(id: PersistentIdentifier) async throws {
        guard let resource = store.fetchResource(id: id) else { return }
        ResourceFileStore.deleteFile(atPath: resource.localPath)
        resource.softDeleted = true
        resource.syncState = .synced
        resource.lastSyncedAt = .now
        try store.save()
    }

    func getCurrentUser() async throws -> User {
        if let cached = store.fetchUser() {
            return cached
        }
        return User(accountKey: accountKey, nickname: NSLocalizedString("account.local-user", comment: "account.local-user"))
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
        throw MoeMemosError.invalidParams
    }

    @MainActor
    func exportSnapshots() -> [LocalMemoExportSnapshot] {
        let memos = store.allMemos(includeDeleted: false)
        return memos.map { memo in
            let resources = memo.resources
                .filter { !$0.softDeleted }
                .map { resource in
                    LocalMemoExportSnapshot.Resource(
                        filename: resource.filename,
                        mimeType: resource.mimeType,
                        localPath: resource.localPath,
                        urlString: resource.urlString
                    )
                }
            return LocalMemoExportSnapshot(
                createdAt: memo.createdAt,
                content: memo.content,
                resources: resources
            )
        }
    }

    // MARK: - Unsupported (Remote Only)

    // Local account never talks to a server.
    // `RemoteService` remains the server API and is used by Explore.
    //
    // We keep this class lean and local-first.
}
