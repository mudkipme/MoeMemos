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

struct Memo: Decodable {
    let id: Int
    let createdTs: Date
    let creatorId: Int
    let content: String
    let pinned: Bool
    let rowStatus: MemosRowStatus
    let updatedTs: Date
    let visibility: MemosVisibility
    
    static let samples: [Memo] = [
        Memo(id: 1, createdTs: .now.addingTimeInterval(-100), creatorId: 1, content: "Hello world\n\nThis is a **multiline** statement and thank you for everything.", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: .private),
        Memo(id: 2, createdTs: .now, creatorId: 1, content: "Hello Memos", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: .private)
    ]
}
