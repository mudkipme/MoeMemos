//
//  Resource.swift
//
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

@Model
public final class Resource {
    @Attribute(.unique)
    public var id: UUID = UUID()
    public var user: User?
    public var filename: String
    public var size: Int
    public var mimeType: String
    @Attribute(.externalStorage)
    public var blob: Data?
    public var memo: Memo?
    public var createdAt: Date
    public var updatedAt: Date
    public var remoteId: String?
    public var synced: Bool
    
    init(id: UUID = UUID(), user: User? = nil, filename: String, size: Int, mimeType: String, blob: Data?, createdAt: Date = .now, updatedAt: Date = .now, remoteId: String? = nil, synced: Bool = false) {
        self.id = id
        self.user = user
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
        self.blob = blob
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteId = remoteId
        self.synced = synced
    }
}
