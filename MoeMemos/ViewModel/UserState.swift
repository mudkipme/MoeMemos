//
//  AppViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/1.
//

import Foundation
import Models
import Account
import MemosService

@MainActor
@Observable class UserState {
    static let shared = UserState()
    
    private(set) var currentUser: MemosUser?
    private(set) var currentStatus: MemosStatus?
    
    func loadCurrentUser() async throws {
        guard let memos = AccountManager.shared.currentService else { throw MemosServiceError.notLogin }
        let response = try await memos.getCurrentUser()
        currentUser = response
    }
    
    func loadCurrentStatus() async throws {
        let response = try await AccountManager.shared.currentService?.getStatus()
        currentStatus = response
    }
    
    func logout() async throws {
        if let account = AccountManager.shared.currentAccount {
            AccountManager.shared.delete(account: account)
        }
        try await loadCurrentUser()
    }
}
