//
//  LocalStoreModels.swift
//
//
//  Created by Mudkip on 2026/2/3.
//

import Foundation
import SwiftData

public enum SyncState: String, Codable, Sendable {
    case synced
    case pendingCreate
    case pendingUpdate
    case pendingDelete
}

@Model
public final class StoredMemo {
    public var accountKey: String
    /// Server identifier. `nil` until this memo is synced to the server.
    public var serverId: String?
    public var content: String
    public var pinned: Bool
    public var rowStatus: RowStatus
    public var visibility: MemoVisibility
    public var createdAt: Date
    public var updatedAt: Date
    public var isDeleted: Bool
    public var syncState: SyncState
    public var lastSyncedAt: Date?
    /// Resources attached to this memo.
    /// - Note: We use `.cascade` so attachments are deleted automatically when a memo is deleted.
    @Relationship(deleteRule: .cascade, inverse: \StoredResource.memo)
    public var resources: [StoredResource]

    public init(
        accountKey: String,
        serverId: String? = nil,
        content: String,
        pinned: Bool,
        rowStatus: RowStatus,
        visibility: MemoVisibility,
        createdAt: Date,
        updatedAt: Date,
        isDeleted: Bool = false,
        syncState: SyncState = .synced,
        lastSyncedAt: Date? = nil,
        resources: [StoredResource] = []
    ) {
        self.accountKey = accountKey
        self.serverId = serverId
        self.content = content
        self.pinned = pinned
        self.rowStatus = rowStatus
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.syncState = syncState
        self.lastSyncedAt = lastSyncedAt
        self.resources = resources
    }
}

@Model
public final class StoredResource {
    public var accountKey: String
    /// Server identifier. `nil` until uploaded.
    public var serverId: String?
    public var filename: String
    public var size: Int
    public var mimeType: String
    public var createdAt: Date
    public var updatedAt: Date
    public var urlString: String
    public var localPath: String?
    public var memo: StoredMemo?
    public var isDeleted: Bool
    public var syncState: SyncState
    public var lastSyncedAt: Date?

    public init(
        accountKey: String,
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
        syncState: SyncState = .synced,
        lastSyncedAt: Date? = nil
    ) {
        self.accountKey = accountKey
        self.serverId = serverId
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.urlString = urlString
        self.localPath = localPath
        self.memo = memo
        self.isDeleted = isDeleted
        self.syncState = syncState
        self.lastSyncedAt = lastSyncedAt
    }
}

public extension StoredResource {
    var url: URL? {
        URL(string: urlString)
    }

    func toResource() -> Resource? {
        guard let url = url else { return nil }
        return Resource(
            filename: filename,
            size: size,
            mimeType: mimeType,
            createdAt: createdAt,
            updatedAt: updatedAt,
            remoteId: serverId,
            url: url
        )
    }
}
