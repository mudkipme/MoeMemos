//
//  File.swift
//  
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

@MainActor
public protocol RemoteService: Sendable {
    func memoVisibilities() -> [MemoVisibility]
    func listMemos() async throws -> [Memo]
    func listArchivedMemos() async throws -> [Memo]
    func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?)
    func createMemo(
        content: String,
        visibility: MemoVisibility?,
        resources: [Resource],
        tags: [String]?,
        createdAt: Date?,
        updatedAt: Date?
    ) async throws -> Memo
    func updateMemo(
        remoteId: String,
        content: String?,
        resources: [Resource]?,
        visibility: MemoVisibility?,
        tags: [String]?,
        pinned: Bool?,
        updatedAt: Date?
    ) async throws -> Memo
    func deleteMemo(remoteId: String) async throws
    func archiveMemo(remoteId: String) async throws
    func restoreMemo(remoteId: String) async throws
    func listTags() async throws -> [Tag]
    func listResources() async throws -> [Resource]
    func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource
    func deleteResource(remoteId: String) async throws
    func getCurrentUser() async throws -> User
    func download(url: URL, mimeType: String?) async throws -> URL
}

/// Local-first service used by the app UI for both Local and Remote accounts.
/// Identifiers are SwiftData `PersistentIdentifier`s, not server ids.
@MainActor
public protocol Service: Sendable {
    func memoVisibilities() -> [MemoVisibility]
    func listMemos() async throws -> [StoredMemo]
    func listArchivedMemos() async throws -> [StoredMemo]
    func memo(id: PersistentIdentifier) -> StoredMemo?

    func createMemo(content: String, visibility: MemoVisibility?, resources: [PersistentIdentifier], tags: [String]?) async throws -> StoredMemo
    func updateMemo(id: PersistentIdentifier, content: String?, resources: [PersistentIdentifier]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> StoredMemo
    func deleteMemo(id: PersistentIdentifier) async throws
    func archiveMemo(id: PersistentIdentifier) async throws
    func restoreMemo(id: PersistentIdentifier) async throws

    func listTags() async throws -> [Tag]
    func listResources() async throws -> [StoredResource]
    func resource(id: PersistentIdentifier) -> StoredResource?
    func createResource(filename: String, data: Data, type: String, memoId: PersistentIdentifier?) async throws -> StoredResource
    func deleteResource(id: PersistentIdentifier) async throws

    func getCurrentUser() async throws -> User
    func ensureLocalResourceFile(id: PersistentIdentifier) async throws -> URL
}

@MainActor
public protocol SyncableService: Sendable {
    func sync() async throws
}

@MainActor
public protocol PendingOperationsService: Sendable {
    func waitForPendingOperations() async
}
