//
//  Memo.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/4.
//

import Foundation

enum MemosRowStatus: String, Decodable {
    case normal = "NORMAL"
    case archived = "ARCHIVED"
}

struct Memo {
    let id: Int
    let createdTs: Date
    let creatorId: Int
    let content: String
    let pinned: Bool
    let rowStatus: MemosRowStatus
    let updatedTs: Date
    let visibility: String
    
    static let samples: [Memo] = [
        Memo(id: 1, createdTs: .now.addingTimeInterval(-100), creatorId: 1, content: "Hello world\n\nThis is a **multiline** statement and thank you for everything.", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: ""),
        Memo(id: 2, createdTs: .now, creatorId: 1, content: "Hello Memos", pinned: false, rowStatus: .normal, updatedTs: .now, visibility: "")
    ]
}
