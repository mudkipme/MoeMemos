//
//  User.swift
//
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation
import SwiftData

public enum UserAvatar: Equatable {
    case data(Data)
    case url(URL)
}

public protocol UserData: Equatable {
    var nickname: String { get }
    var defaultVisibility: MemoVisibility { get }
    var creationDate: Date { get }
    var avatar: UserAvatar? { get }
}

public struct RemoteUser: UserData, Sendable, Hashable {
    public var nickname: String
    public var defaultVisibility: MemoVisibility
    public var creationDate: Date
    public var remoteId: String?
    public var avatarUrl: URL?
    
    public var avatar: UserAvatar? { avatarUrl.map { .url($0) } }
}

@Model
public final class User: UserData {
    @Attribute(.unique)
    public var accountKey: String
    public var nickname: String
    @Attribute(.externalStorage)
    public var avatarData: Data?
    public var defaultVisibility: MemoVisibility
    public var creationDate: Date
    public var email: String?
    public var remoteId: String?
    
    public init(accountKey: String, nickname: String, avatarData: Data? = nil, defaultVisibility: MemoVisibility = .private, creationDate: Date = .now, email: String? = nil, remoteId: String? = nil) {
        self.accountKey = accountKey
        self.nickname = nickname
        self.avatarData = avatarData
        self.defaultVisibility = defaultVisibility
        self.creationDate = creationDate
        self.email = email
        self.remoteId = remoteId
    }
    
    public var avatar: UserAvatar? { avatarData.map { .data($0) } }
}

@MainActor
public final class UserModelActor {
    public init() {}
    
    public func deleteUser(_ context: ModelContext, accountKey: String) throws {
        try context.delete(model: User.self, where: #Predicate<User> { user in user.accountKey == accountKey })
    }
}
