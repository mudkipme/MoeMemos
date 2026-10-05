//
//  AccountManager.swift
//  
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import Observation
import MemosV0Service
import MemosV1Service
import SwiftData
import Models
import Factory

@MainActor
@Observable public final class AccountManager: @unchecked Sendable {
    @ObservationIgnored private let preferences: UserDefaults
    private var currentAccountKey: String {
        get { preferences.string(forKey: "currentAccountKey") ?? "" }
        set { preferences.set(newValue, forKey: "currentAccountKey") }
    }
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
    
    public private(set) var currentAccount: Account? {
        didSet {
            if shouldPersistCurrentAccountKey {
                currentAccountKey = currentAccount?.key ?? ""
            }
            currentService = makeService(for: currentAccount)
            currentRemoteService = makeRemoteService(for: currentAccount)
        }
    }
    
    public init(modelContext: ModelContext, preferences: UserDefaults = UserDefaults(suiteName: AppInfo.groupContainerIdentifier)!) {
        self.modelContext = modelContext
        self.preferences = preferences
        if currentAccountKey.isEmpty {
            currentAccount = nil
        } else {
            currentAccount = Account.retrieve(accountKey: currentAccountKey)
        }
        shouldPersistCurrentAccountKey = true

        try? ResourceFileStore.cleanupOrphanedFiles(context: modelContext)
    }
    
    public func unsyncedMemoCount(for accountKey: String) -> Int {
        let descriptor = FetchDescriptor<StoredMemo>(
            predicate: #Predicate { memo in
                memo.accountKey == accountKey
            }
        )
        let memos = (try? modelContext.fetch(descriptor)) ?? []
        return memos.filter { $0.syncState != .synced }.count
    }

    public func delete(account: Account) throws {
        if case .local = account {
            return
        }
        let deletedAccountKey = account.key
        let deletingCurrentAccount = currentAccount?.key == deletedAccountKey

        try deleteLocalData(accountKey: account.key)
        account.delete()

        if deletingCurrentAccount {
            currentAccount = fallbackAccount(excluding: deletedAccountKey)
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
        let identifiers = Set(memos.map { MemoEntityIdentifier(accountKey: $0.accountKey, persistentID: $0.id) })
        for memo in memos {
            modelContext.delete(memo)
        }

        let users = try modelContext.fetch(userDescriptor)
        for user in users {
            modelContext.delete(user)
        }

        try modelContext.save()
        MemoChanges.shared.didSave(identifiers: identifiers, container: modelContext.container)
        ResourceFileStore.deleteAccountFiles(accountKey: accountKey)
        try? ResourceFileStore.cleanupOrphanedFiles(context: modelContext)
    }

    @MainActor
    public func loginLocal() async throws {
        let account = Account.local
        let user = UserSnapshot.local(accountKey: account.key)
        try persistLoggedInAccount(account: account, user: user)
    }
    
    @MainActor
    public func loginMemosV0(hostURL: URL, accessToken: String) async throws {
        let client = MemosV0Service(hostURL: hostURL, accessToken: accessToken)
        let user = try await client.getCurrentUser()
        guard let id = user.remoteId else { throw MoeMemosError.unsupportedVersion }
        let account = Account.memosV0(host: hostURL.absoluteString, id: id, accessToken: accessToken)
        try persistLoggedInAccount(account: account, user: user)
    }
    
    @MainActor
    public func loginMemosV1(hostURL: URL, accessToken: String) async throws {
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
        let existingUser = try modelContext.fetch(descriptor).first
        let existingSnapshot = existingUser.map(UserSnapshot.init(user:))
        let previousAccount = Account.retrieve(accountKey: account.key)
        let insertedUser: User?

        if let existingUser {
            user.apply(to: existingUser)
            insertedUser = nil
        } else {
            let newUser = user.toUserModel()
            modelContext.insert(newUser)
            insertedUser = newUser
        }

        do {
            try account.save()
            try modelContext.save()
        } catch {
            if let existingUser, let existingSnapshot {
                existingSnapshot.apply(to: existingUser)
            } else if let insertedUser {
                modelContext.delete(insertedUser)
            }
            _ = try? modelContext.save()

            if let previousAccount {
                try? previousAccount.save()
            } else {
                account.delete()
            }
            throw error
        }

        currentAccount = account
    }

    public func service(for accountKey: String) -> Service? {
        guard let account = account(for: accountKey) else { return nil }
        return makeService(for: account)
    }

    public func selectAccount(key: String) throws {
        guard let account = account(for: key) else { throw MoeMemosError.notLogin }
        currentAccount = account
    }

    public var currentUser: User? {
        guard let key = currentAccount?.key else { return nil }
        return try? modelContext.fetch(FetchDescriptor<User>(predicate: #Predicate { $0.accountKey == key })).first
    }

    public func localExportSnapshots(for accountKey: String) -> [LocalMemoExportSnapshot]? {
        (service(for: accountKey) as? LocalService)?.exportSnapshots()
    }

    public func account(for accountKey: String) -> Account? {
        return Account.retrieve(accountKey: accountKey)
    }

    private func fallbackAccount(excluding accountKey: String) -> Account? {
        let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.creationDate)])
        let users = (try? modelContext.fetch(descriptor)) ?? []
        for user in users.reversed() where user.accountKey != accountKey {
            if let account = account(for: user.accountKey) {
                return account
            }
        }
        return nil
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
