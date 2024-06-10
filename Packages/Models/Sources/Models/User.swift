//
//  User.swift
//
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

@Model
public final class User {
    @Attribute(.unique)
    public var accountKey: String
    public var nickname: String
    @Attribute(.externalStorage)
    public var avatarData: Data?
    public var defaultVisibility: MemoVisibility
    public var creationDate: Date
    public var remoteId: String?
    
    public init(accountKey: String, nickname: String, avatarData: Data? = nil, defaultVisibility: MemoVisibility = .private, creationDate: Date = .now, remoteId: String? = nil) {
        self.accountKey = accountKey
        self.nickname = nickname
        self.avatarData = avatarData
        self.defaultVisibility = defaultVisibility
        self.creationDate = creationDate
        self.remoteId = remoteId
    }
}
