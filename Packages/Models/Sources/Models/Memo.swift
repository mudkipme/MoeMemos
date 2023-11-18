//
//  Memo.swift
//
//
//  Created by Mudkip on 2023/11/18.
//

import Foundation
import SwiftData

enum RowStatus: Codable {
    case normal
    case archived
}

enum MemoVisibility: Codable {
    case `private`
    case `protected`
    case `public`
}

@Model
class Memo {
    @Attribute(.unique)
    var id: UUID
    var account: Account
    var content: String
    var pinned: Bool
    var rowStatus: RowStatus
    var visibility: MemoVisibility
    var createdAt: Date
    var updatedAt: Date
    var remoteId: String? = nil
    
    init(id: UUID, account: Account, content: String, pinned: Bool, rowStatus: RowStatus, visibility: MemoVisibility, createdAt: Date, updatedAt: Date, remoteId: String? = nil) {
        self.id = id
        self.account = account
        self.content = content
        self.pinned = pinned
        self.rowStatus = rowStatus
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteId = remoteId
    }
}
