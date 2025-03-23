//
//  Resource.swift
//
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

public struct Resource: Identifiable, Equatable, Sendable, Hashable {
    public var filename: String
    public var size: Int
    public var mimeType: String
    public var createdAt: Date
    public var updatedAt: Date
    public var remoteId: String?
    public var url: URL
    
    public init(filename: String, size: Int, mimeType: String, createdAt: Date = .now, updatedAt: Date = .now, remoteId: String? = nil, url: URL) {
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteId = remoteId
        self.url = url
    }
    
    public var id: String { remoteId ?? "" }
}

@Model
public final class ResourceModel {
    #Unique<ResourceModel>([\.user, \.remoteId])
    public var user: User?
    public var remoteId: String?
    public var synced: Bool?
    public var createdAt: Date
    public var updatedAt: Date

    public var filename: String
    public var size: Int
    public var mimeType: String
    public var url: URL?
    public var memo: MemoModel?
    
    @Attribute(.externalStorage)
    public var data: Data?
    
    public init(user: User? = nil, remoteId: String? = nil, synced: Bool? = nil, createdAt: Date = .now, updatedAt: Date = .now, filename: String, size: Int, mimeType: String, url: URL? = nil, memo: MemoModel?, data: Data? = nil) {
        self.user = user
        self.remoteId = remoteId
        self.synced = synced
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
        self.url = url
        self.memo = memo
        self.data = data
    }
}
