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
    var showingLogin = false
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
    
    func signIn(memosHost: String, username: String, password: String) async throws {
        guard let url = URL(string: memosHost) else { throw MemosServiceError.invalidParams }
        let client = MemosService(hostURL: url, accessToken: nil)
        let (user, accessToken) = try await client.signIn(username: username, password: password)
        guard let accessToken = accessToken else { throw MemosServiceError.unsupportedVersion }
        try AccountManager.shared.add(account: .memos(host: memosHost, id: "\(user.id)", accessToken: accessToken))
        let response = try await AccountManager.shared.currentService?.getCurrentUser()
        currentUser = response
    }
    
    func signIn(memosHost: String, accessToken: String) async throws {
        guard let url = URL(string: memosHost) else { throw MemosServiceError.invalidParams }
        let client = MemosService(hostURL: url, accessToken: accessToken)
        let response = try await client.getCurrentUser()
        try AccountManager.shared.add(account: .memos(host: memosHost, id: "\(response.id)", accessToken: accessToken))
        currentUser = response
    }
    
    func logout() async throws {
        if let account = AccountManager.shared.currentAccount {
            AccountManager.shared.delete(account: account)
        }
        try await loadCurrentUser()
    }
}
