//
//  AccountManager.swift
//  
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import SwiftUI
import Models
import Factory

@Observable public final class AccountManager {
    @ObservationIgnored @AppStorage("currentAccountKey", store: UserDefaults(suiteName: AppInfo.groupContainerIdentifier))
    private var currentAccountKey: String = ""
    @ObservationIgnored public private(set) var currentService: RemoteService?
    
    public var mustCurrentService: RemoteService {
        get throws {
            guard let service = currentService else { throw MoeMemosError.notLogin }
            return service
        }
    }
    
    public private(set) var accounts: [Account]
    public internal(set) var currentAccount: Account? {
        didSet {
            currentAccountKey = currentAccount?.key ?? ""
            currentService = currentAccount?.remoteService()
        }
    }
    
    public init() {
        accounts = Account.retriveAll()
        if !currentAccountKey.isEmpty, let currentAccount = accounts.first(where: { $0.key == currentAccountKey }) {
            self.currentAccount = currentAccount
        } else {
            self.currentAccount = accounts.last
        }
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
}

public extension Container {
    var accountManager: Factory<AccountManager> {
        self { AccountManager() }.shared
    }
}
