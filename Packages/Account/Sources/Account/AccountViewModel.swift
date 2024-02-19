//
//  AccountViewModel.swift
//
//
//  Created by Mudkip on 2023/11/25.
//

import Foundation
import SwiftData
import Models

@MainActor
@Observable public class AccountViewModel {
    private var currentContext: ModelContext
    private var accountManager: AccountManager
    public static let shared = AccountViewModel()
    
    public init(currentContext: ModelContext = AppInfo.shared.modelContext, accountManager: AccountManager = AccountManager.shared) {
        self.currentContext = currentContext
        self.accountManager = accountManager
        
        _ = withObservationTracking {
            accountManager.accounts
        } onChange: {
            Task {
                try await self.reloadUsers()
            }
        }
    }
    
    public private(set) var users = [User]()
    public var currentUser: User? {
        if let account = self.accountManager.currentAccount {
            return users.first { $0.accountKey == account.key }
        }
        return nil
    }
    
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
        
        users = allUsers
    }
    
    func logout() async throws {
        if let account = accountManager.currentAccount {
            accountManager.delete(account: account)
        }
    }
}
