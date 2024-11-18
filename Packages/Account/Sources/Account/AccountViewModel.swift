//
//  AccountViewModel.swift
//
//
//  Created by Mudkip on 2024/6/5.
//

import Foundation
import SwiftData
import Models
import Factory
import MemosV1Service
import MemosV0Service

@Observable public final class AccountViewModel: @unchecked Sendable {
    private var currentContext: ModelContext
    private var accountManager: AccountManager
    public var showingAddAccount = false

    public init(currentContext: ModelContext, accountManager: AccountManager) {
        self.currentContext = currentContext
        self.accountManager = accountManager
        users = (try? currentContext.fetch(FetchDescriptor<User>())) ?? []
    }
    
    public private(set) var users: [User]
    public var currentUser: User? {
        if let account = self.accountManager.currentAccount {
            return users.first { $0.accountKey == account.key }
        }
        return nil
    }
    
    @MainActor
    public func reloadUsers() async throws {
        let savedUsers = try currentContext.fetch(FetchDescriptor<User>())
        var allUsers = [User]()
        for account in accountManager.accounts {
            if accountManager.currentAccount == account {
                guard let currentService = accountManager.currentService else { throw MoeMemosError.notLogin }
                let user = try await currentService.getCurrentUser()
                if let existingUser = savedUsers.first(where: { $0.accountKey == account.key }) {
                    existingUser.avatarData = user.avatarData
                    existingUser.nickname = user.nickname
                    existingUser.defaultVisibility = user.defaultVisibility
                } else {
                    currentContext.insert(user)
                }
                allUsers.append(user)
            } else if let user = savedUsers.first(where: { $0.accountKey == account.key }) {
                allUsers.append(user)
            } else if let user = try? await account.toUser() {
                allUsers.append(user)
                currentContext.insert(user)
            }
        }

        // Remove removed users
        savedUsers.filter { user in !accountManager.accounts.contains { $0.key == user.accountKey } }.forEach { user in
            currentContext.delete(user)
        }
        try currentContext.save()
        users = allUsers
    }
    
    @MainActor
    func logout(account: Account) async throws {
        try? await account.remoteService()?.logout()
        accountManager.delete(account: account)
        try await reloadUsers()
    }
    
    @MainActor
    func switchTo(accountKey: String) async throws {
        guard let account = accountManager.accounts.first(where: { $0.key == accountKey }) else { return }
        accountManager.currentAccount = account
        try await reloadUsers()
    }
    
    @MainActor
    func loginMemosV0(hostURL: URL, username: String, password: String) async throws {
        let client = MemosV0Service(hostURL: hostURL, accessToken: nil)
        let (user, accessToken) = try await client.signIn(username: username, password: password)
        guard let accessToken = accessToken else { throw MoeMemosError.unsupportedVersion }
        let account = Account.memosV0(host: hostURL.absoluteString, id: "\(user.id)", accessToken: accessToken)
        let accountKey = account.key
        try currentContext.delete(model: User.self, where: #Predicate<User> { user in user.accountKey == accountKey })
        try accountManager.add(account: account)
        try await reloadUsers()
    }
    
    @MainActor
    func loginMemosV0(hostURL: URL, accessToken: String) async throws {
        let client = MemosV0Service(hostURL: hostURL, accessToken: accessToken)
        let user = try await client.getCurrentUser()
        guard let id = user.remoteId else { throw MoeMemosError.unsupportedVersion }
        let account = Account.memosV0(host: hostURL.absoluteString, id: id, accessToken: accessToken)
        let accountKey = account.key
        try currentContext.delete(model: User.self, where: #Predicate<User> { user in user.accountKey == accountKey })
        try accountManager.add(account: account)
        try await reloadUsers()
    }
    
    @MainActor
    func loginMemosV1(hostURL: URL, username: String, password: String) async throws {
        let client = MemosV1Service(hostURL: hostURL, accessToken: nil, userId: nil)
        let (user, accessToken) = try await client.signIn(username: username, password: password)
        guard let accessToken = accessToken, let userId = user.id else { throw MoeMemosError.unsupportedVersion }
        let account = Account.memosV1(host: hostURL.absoluteString, id: "\(userId)", accessToken: accessToken)
        let accountKey = account.key
        try currentContext.delete(model: User.self, where: #Predicate<User> { user in user.accountKey == accountKey })
        try accountManager.add(account: account)
        try await reloadUsers()
    }
    
    @MainActor
    func loginMemosV1(hostURL: URL, accessToken: String) async throws {
        let client = MemosV1Service(hostURL: hostURL, accessToken: accessToken, userId: nil)
        let user = try await client.getCurrentUser()
        guard let id = user.remoteId else { throw MoeMemosError.unsupportedVersion }
        let account = Account.memosV1(host: hostURL.absoluteString, id: id, accessToken: accessToken)
        let accountKey = account.key
        try currentContext.delete(model: User.self, where: #Predicate<User> { user in user.accountKey == accountKey })
        try accountManager.add(account: account)
        try await reloadUsers()
    }
}

public extension Container {
    var accountViewModel: Factory<AccountViewModel> {
        self { AccountViewModel(currentContext: self.appInfo().modelContext, accountManager: self.accountManager()) }.shared
    }
}
