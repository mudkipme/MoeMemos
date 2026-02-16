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

@MainActor
@Observable public final class AccountViewModel: @unchecked Sendable {
    @ObservationIgnored private var currentContext: ModelContext
    private var accountManager: AccountManager

    public init(currentContext: ModelContext, accountManager: AccountManager) {
        self.currentContext = currentContext
        self.accountManager = accountManager
        users = []
        refreshUsers()
    }
    
    public private(set) var users: [User]
    public var currentUser: User? {
        if let account = self.accountManager.currentAccount {
            return users.first { $0.accountKey == account.key }
        }
        return nil
    }
    
    public func refreshUsers() {
        let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.creationDate)])
        users = (try? currentContext.fetch(descriptor)) ?? []
    }
    
    @MainActor
    func logout(account: Account) async throws {
        try accountManager.delete(account: account)
        refreshUsers()
    }
    
    @MainActor
    func switchTo(accountKey: String) async throws {
        guard let account = accountManager.account(for: accountKey) else { throw MoeMemosError.notLogin }
        accountManager.currentAccount = account
        refreshUsers()
    }

    @MainActor
    func loginLocal() async throws {
        let account = Account.local
        let user = UserSnapshot.local(accountKey: account.key)
        try persistLoggedInAccount(account: account, user: user)
    }
    
    @MainActor
    func loginMemosV0(hostURL: URL, accessToken: String) async throws {
        let client = MemosV0Service(hostURL: hostURL, accessToken: accessToken)
        let user = try await client.getCurrentUser()
        guard let id = user.remoteId else { throw MoeMemosError.unsupportedVersion }
        let account = Account.memosV0(host: hostURL.absoluteString, id: id, accessToken: accessToken)
        try persistLoggedInAccount(account: account, user: user)
    }
    
    @MainActor
    func loginMemosV1(hostURL: URL, accessToken: String) async throws {
        let client = MemosV1Service(hostURL: hostURL, accessToken: accessToken, userId: nil)
        let user = try await client.getCurrentUser()
        guard let id = user.remoteId else { throw MoeMemosError.unsupportedVersion }
        let account = Account.memosV1(host: hostURL.absoluteString, id: id, accessToken: accessToken)
        try persistLoggedInAccount(account: account, user: user)
    }
    
    private func persistLoggedInAccount(account: Account, user: UserSnapshot) throws {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { storedUser in
                storedUser.accountKey == account.key
            }
        )
        let existingUser = try currentContext.fetch(descriptor).first
        let existingSnapshot = existingUser.map(UserSnapshot.init(user:))
        let previousAccount = Account.retrieve(accountKey: account.key)
        let insertedUser: User?

        if let existingUser {
            user.apply(to: existingUser)
            insertedUser = nil
        } else {
            let newUser = user.toUserModel()
            currentContext.insert(newUser)
            insertedUser = newUser
        }

        do {
            try account.save()
            try currentContext.save()
        } catch {
            if let existingUser, let existingSnapshot {
                existingSnapshot.apply(to: existingUser)
            } else if let insertedUser {
                currentContext.delete(insertedUser)
            }
            _ = try? currentContext.save()

            if let previousAccount {
                try? previousAccount.save()
            } else {
                account.delete()
            }
            throw error
        }

        accountManager.currentAccount = account
        refreshUsers()
    }
}

public extension Container {
    @MainActor
    var accountViewModel: Factory<AccountViewModel> {
        self { @MainActor in
            AccountViewModel(currentContext: self.appInfo().modelContext, accountManager: self.accountManager())
        }.shared
    }
}
