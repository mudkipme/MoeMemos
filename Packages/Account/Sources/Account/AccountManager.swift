//
//  AccountManager.swift
//  
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import SwiftUI
import SwiftData
import Models
import Factory

@MainActor
@Observable public final class AccountManager: @unchecked Sendable {
    @ObservationIgnored @AppStorage("currentAccountKey", store: UserDefaults(suiteName: AppInfo.groupContainerIdentifier))
    private var currentAccountKey: String = ""
    @ObservationIgnored private var shouldPersistCurrentAccountKey = false
    @ObservationIgnored public private(set) var currentService: Service?
    @ObservationIgnored public private(set) var currentRemoteService: RemoteService?
    @ObservationIgnored private let modelContext: ModelContext
    
    public var mustCurrentService: Service {
        get throws {
            guard let service = currentService else { throw MoeMemosError.notLogin }
            return service
        }
    }

    public var mustCurrentRemoteService: RemoteService {
        get throws {
            guard let service = currentRemoteService else { throw MoeMemosError.notLogin }
            return service
        }
    }
    
    public private(set) var accounts: [Account]
    public internal(set) var currentAccount: Account? {
        didSet {
            if shouldPersistCurrentAccountKey {
                currentAccountKey = currentAccount?.key ?? ""
            }
            currentService = makeService(for: currentAccount)
            currentRemoteService = makeRemoteService(for: currentAccount)
        }
    }
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        accounts = Account.retriveAll()
        if !currentAccountKey.isEmpty, let currentAccount = accounts.first(where: { $0.key == currentAccountKey }) {
            self.currentAccount = currentAccount
        } else {
            self.currentAccount = accounts.last
        }
        shouldPersistCurrentAccountKey = true

        try? ResourceFileStore.cleanupOrphanedFiles(context: modelContext)
    }
    
    internal func add(account: Account) throws {
        try account.save()
        accounts = Account.retriveAll()
        currentAccount = account
    }
    
    internal func unsyncedMemoCount(for accountKey: String) -> Int {
        let descriptor = FetchDescriptor<StoredMemo>(
            predicate: #Predicate { memo in
                memo.accountKey == accountKey
            }
        )
        let memos = (try? modelContext.fetch(descriptor)) ?? []
        return memos.filter { $0.syncState != .synced }.count
    }

    internal func delete(account: Account) throws {
        if case .local = account {
            return
        }
        try deleteLocalData(accountKey: account.key)
        accounts.removeAll { $0.key == account.key }
        account.delete()
        if currentAccount?.key == account.key {
            currentAccount = accounts.last
        }
    }

    private func deleteLocalData(accountKey: String) throws {
        let memoDescriptor = FetchDescriptor<StoredMemo>(
            predicate: #Predicate { memo in
                memo.accountKey == accountKey
            }
        )
        let resourceDescriptor = FetchDescriptor<StoredResource>(
            predicate: #Predicate { resource in
                resource.accountKey == accountKey
            }
        )
        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { user in
                user.accountKey == accountKey
            }
        )

        let resources = try modelContext.fetch(resourceDescriptor)
        for resource in resources {
            ResourceFileStore.deleteFile(atPath: resource.localPath)
            modelContext.delete(resource)
        }

        let memos = try modelContext.fetch(memoDescriptor)
        for memo in memos {
            modelContext.delete(memo)
        }

        let users = try modelContext.fetch(userDescriptor)
        for user in users {
            modelContext.delete(user)
        }

        try modelContext.save()
        ResourceFileStore.deleteAccountFiles(accountKey: accountKey)
        try? ResourceFileStore.cleanupOrphanedFiles(context: modelContext)
    }

    public func service(for accountKey: String) -> Service? {
        guard let account = accounts.first(where: { $0.key == accountKey }) else { return nil }
        return makeService(for: account)
    }

    private func makeService(for account: Account?) -> Service? {
        guard let account else { return nil }
        switch account {
        case .local:
            return LocalService(context: modelContext, accountKey: account.key)
        case .memosV0, .memosV1:
            guard let remote = account.remoteService() else { return nil }
            return SyncingRemoteService(remote: remote, context: modelContext, accountKey: account.key)
        }
    }

    private func makeRemoteService(for account: Account?) -> RemoteService? {
        guard let account else { return nil }
        switch account {
        case .local:
            return nil
        case .memosV0, .memosV1:
            return account.remoteService()
        }
    }
}

public extension Container {
    @MainActor
    var accountManager: Factory<AccountManager> {
        self { @MainActor in
            AccountManager(modelContext: self.appInfo().modelContext)
        }.shared
    }
}
