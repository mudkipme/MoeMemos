//
//  AccountViewModel.swift
//
//
//  Created by Mudkip on 2024/6/5.
//

import MemoData
import Foundation
import SwiftData
import Models
import Factory

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
        await MemoChanges.shared.flush()
        refreshUsers()
    }
    
    @MainActor
    func switchTo(accountKey: String) async throws {
        try accountManager.selectAccount(key: accountKey)
        refreshUsers()
    }

    func loginLocal() async throws {
        try await accountManager.loginLocal()
        refreshUsers()
    }

    func loginMemosV0(hostURL: URL, accessToken: String) async throws {
        try await accountManager.loginMemosV0(hostURL: hostURL, accessToken: accessToken)
        refreshUsers()
    }

    func loginMemosV1(hostURL: URL, accessToken: String) async throws {
        try await accountManager.loginMemosV1(hostURL: hostURL, accessToken: accessToken)
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
