//
//  User.swift
//
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

@Model
public class User {
    @Attribute(.unique)
    public var accountKey: String
    public var nickname: String
    @Attribute(.externalStorage)
    public var avatarData: Data? = nil
    public var defaultVisibility: MemoVisibility
    public var creationDate: Date
    
    public init(accountKey: String, nickname: String, avatarData: Data? = nil, defaultVisibility: MemoVisibility = .private, creationDate: Date = .now) {
        self.accountKey = accountKey
        self.nickname = nickname
        self.avatarData = avatarData
        self.defaultVisibility = defaultVisibility
        self.creationDate = creationDate
    }
}
