//
//  Resource.swift
//
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation

public struct Resource {
    public var filename: String
    public var size: Int
    public var mimeType: String
    public var createdAt: Date
    public var updatedAt: Date
    public var remoteId: String?
    public var url: URL
    
    init(filename: String, size: Int, mimeType: String, createdAt: Date = .now, updatedAt: Date = .now, remoteId: String? = nil, url: URL) {
        self.filename = filename
        self.size = size
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteId = remoteId
        self.url = url
    }
}
