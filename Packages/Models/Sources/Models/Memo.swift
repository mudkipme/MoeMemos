//
//  Memo.swift
//
//
//  Created by Mudkip on 2023/11/18.
//

import Foundation

public enum RowStatus: Codable, Sendable {
    case normal
    case archived
}

public enum MemoVisibility: Codable, Sendable {
    case `private`
    case local
    case `public`
    case unlisted
    case direct
}

public struct Memo: Equatable, Sendable, Hashable {
    public var user: RemoteUser?
    public var content: String
    public var pinned: Bool
    public var rowStatus: RowStatus
    public var visibility: MemoVisibility
    public var resources: [Resource]
    public var createdAt: Date
    public var updatedAt: Date
    public var remoteId: String?
    
    public init(user: RemoteUser? = nil, content: String, pinned: Bool = false, rowStatus: RowStatus = .normal, visibility: MemoVisibility = .private, resources: [Resource] = [], createdAt: Date = .now, updatedAt: Date = .now, remoteId: String? = nil) {
        self.user = user
        self.content = content
        self.pinned = pinned
        self.rowStatus = rowStatus
        self.visibility = visibility
        self.resources = resources
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteId = remoteId
    }
}
