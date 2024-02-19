//
//  Memo.swift
//
//
//  Created by Mudkip on 2023/11/18.
//

import Foundation
import SwiftData

public enum RowStatus: Codable {
    case normal
    case archived
}

public enum MemoVisibility: Codable {
    case `private`
    case local
    case `public`
    case unlisted
    case direct
}

@Model
public final class Memo {
    @Attribute(.unique)
    public var id: UUID = UUID()
    public var user: User?
    public var content: String
    public var pinned: Bool
    public var rowStatus: RowStatus
    public var visibility: MemoVisibility
    @Relationship(deleteRule: .cascade, inverse: \Resource.memo)
    public var resources: [Resource]
    public var createdAt: Date
    public var updatedAt: Date
    public var remoteId: String?
    public var synced: Bool
    
    public init(id: UUID = UUID(), user: User? = nil, content: String, pinned: Bool = false, rowStatus: RowStatus = .normal, visibility: MemoVisibility = .private, resources: [Resource] = [], createdAt: Date = .now, updatedAt: Date = .now, remoteId: String? = nil, synced: Bool = false) {
        self.id = id
        self.user = user
        self.content = content
        self.pinned = pinned
        self.rowStatus = rowStatus
        self.visibility = visibility
        self.resources = resources
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteId = remoteId
        self.synced = synced
    }
}
