//
//  File.swift
//  
//
//  Created by Mudkip on 2024/6/5.
//

import Foundation
import SwiftData
import Models
import Factory

@Observable public final class AccountViewModel {
    private var currentContext: ModelContext
    private var accountManager: AccountManager

    public init(currentContext: ModelContext, accountManager: AccountManager) {
        self.currentContext = currentContext
        self.accountManager = accountManager
    }
    
    public private(set) var users = [User]()
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
            if let user = savedUsers.first(where: { $0.accountKey == account.key }) {
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
    
    func logout() async throws {
        if let account = accountManager.currentAccount {
            accountManager.delete(account: account)
        }
    }

}

public extension Container {
    var accountViewModel: Factory<AccountViewModel> {
        self { AccountViewModel(currentContext: self.appInfo().modelContext, accountManager: self.accountManager()) }.shared
    }
}
