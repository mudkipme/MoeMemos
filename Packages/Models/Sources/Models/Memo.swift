//
//  Memo.swift
//
//
//  Created by Mudkip on 2023/11/18.
//

import Foundation
import SwiftData

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

@Model
public final class MemoModel {
    #Unique<MemoModel>([\.user, \.remoteId])
    public var user: User?
    public var remoteId: String?
    public var synced: Bool?
    public var createdAt: Date
    public var updatedAt: Date
    
    public var content: String
    public var pinned: Bool
    public var rowStatus: RowStatus
    public var visibility: MemoVisibility
    
    @Relationship(deleteRule: .cascade, inverse: \ResourceModel.memo)
    public var resoruces: [ResourceModel]
    public var tags: [Tag]
    
    public init(user: User? = nil, remoteId: String? = nil, synced: Bool? = nil, createdAt: Date = .now, updatedAt: Date = .now, content: String, pinned: Bool = false, rowStatus: RowStatus = .normal, visibility: MemoVisibility, resoruces: [ResourceModel] = [], tags: [Tag] = []) {
        self.user = user
        self.remoteId = remoteId
        self.synced = synced
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.content = content
        self.pinned = pinned
        self.rowStatus = rowStatus
        self.visibility = visibility
        self.resoruces = resoruces
        self.tags = tags
    }
}
