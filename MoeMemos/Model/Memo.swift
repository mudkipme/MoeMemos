//
//  Memo.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import Foundation

enum MemosVisibility: String, Decodable, Encodable {
    case `public` = "PUBLIC"
    case `protected` = "PROTECTED"
    case `private` = "PRIVATE"
}

enum MemosRowStatus: String, Decodable, Encodable {
    case normal = "NORMAL"
    case archived = "ARCHIVED"
}

struct Memo: Decodable, Equatable {
    let id: Int
    let createdTs: Date
    let creatorId: Int
    var content: String
    var pinned: Bool
    let rowStatus: MemosRowStatus
    let updatedTs: Date
    let visibility: MemosVisibility
    let resourceList: [Resource]?
}

struct Tag: Identifiable, Hashable {
    let name: String
    
    var id: String { name }
}
