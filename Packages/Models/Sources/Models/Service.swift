//
//  File.swift
//  
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation

@MainActor
public protocol RemoteService: Sendable {
    func memoVisibilities() -> [MemoVisibility]
    func listMemos() async throws -> [Memo]
    func listArchivedMemos() async throws -> [Memo]
    func listWorkspaceMemos(pageSize: Int, pageToken: String?) async throws -> (list: [Memo], nextPageToken: String?)
    func createMemo(content: String, visibility: MemoVisibility?, resources: [Resource], tags: [String]?) async throws -> Memo
    func updateMemo(remoteId: String, content: String?, resources: [Resource]?, visibility: MemoVisibility?, tags: [String]?, pinned: Bool?) async throws -> Memo
    func deleteMemo(remoteId: String) async throws
    func archiveMemo(remoteId: String) async throws
    func restoreMemo(remoteId: String) async throws
    func listTags() async throws -> [Tag]
    func deleteTag(name: String) async throws
    func listResources() async throws -> [Resource]
    func createResource(filename: String, data: Data, type: String, memoRemoteId: String?) async throws -> Resource
    func deleteResource(remoteId: String) async throws
    func getCurrentUser() async throws -> User
    func download(url: URL, mimeType: String?) async throws -> URL
    func getMemo(remoteId: String) async throws -> Memo
}
