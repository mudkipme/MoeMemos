//
//  AccountManager.swift
//  
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import SwiftUI
import Models
import MemosService

@Observable public class AccountManager {
    public static let shared = AccountManager()

    @ObservationIgnored @AppStorage("currentAccountKey", store: UserDefaults(suiteName: AppInfo.groupContainerIdentifier))
    private var currentAccountKey: String = ""
    @ObservationIgnored public private(set) var currentService: MemosService?
    
    public var mustCurrentService: MemosService {
        get throws {
            guard let service = currentService else { throw MemosServiceError.notLogin }
            return service
        }
    }
    
    public var accounts: [Account]
    public var currentAccount: Account? {
        didSet {
            currentAccountKey = currentAccount?.key ?? ""
            currentService = currentAccount?.memosService
        }
    }
    
    init() {
        accounts = Account.retriveAll()
        if !currentAccountKey.isEmpty, let currentAccount = accounts.first(where: { $0.key == currentAccountKey }) {
            self.currentAccount = currentAccount
        } else {
            self.currentAccount = accounts.last
        }
    }
    
    public func add(account: Account) throws {
        try account.save()
        accounts = Account.retriveAll()
        currentAccount = account
    }
    
    public func delete(account: Account) {
        accounts.removeAll { $0.key == account.key }
        account.delete()
        if currentAccount?.key == account.key {
            currentAccount = accounts.last
        }
    }
}
