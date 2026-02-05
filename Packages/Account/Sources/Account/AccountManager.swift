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
            currentAccountKey = currentAccount?.key ?? ""
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
        currentService = makeService(for: currentAccount)
        currentRemoteService = makeRemoteService(for: currentAccount)

        try? ResourceFileStore.cleanupOrphanedFiles(context: modelContext)
    }
    
    internal func add(account: Account) throws {
        try account.save()
        accounts = Account.retriveAll()
        currentAccount = account
    }
    
    internal func delete(account: Account) {
        accounts.removeAll { $0.key == account.key }
        account.delete()
        if currentAccount?.key == account.key {
            currentAccount = accounts.last
        }
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
