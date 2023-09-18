//
//  AppViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/1.
//

import Foundation

@MainActor
class UserState: ObservableObject {
    let memosManager: MemosManager
    init(memosManager: MemosManager = .shared) {
        self.memosManager = memosManager
    }
    
    static let shared = UserState()
    
    var memos: Memos { get throws { try memosManager.api } }
    var status: MemosServerStatus? { memosManager.memos?.status }
    
    @Published private(set) var currentUser: MemosUser?
    @Published var showingLogin = false
    
    func reset(memosHost: String, accessToken: String?, openId: String?) async throws {
        try await memosManager.reset(memosHost: memosHost, accessToken: accessToken, openId: openId)
        currentUser = nil
    }
    
    func loadCurrentUser() async throws {
        let response = try await memos.me()
        currentUser = response
    }
    
    func signIn(memosHost: String, input: MemosSignIn.Input) async throws {
        guard let url = URL(string: memosHost) else { throw MemosError.invalidParams }
        
        let client = try await Memos.create(host: url, accessToken: nil, openId: nil)
        try await client.signIn(data: input)
        
        let response = try await client.me()
        await memosManager.reset(memosHost: url, accessToken: nil, openId: nil)
        currentUser = response
    }
    
    func signIn(memosHost: String, accessToken: String) async throws {
        guard let url = URL(string: memosHost) else { throw MemosError.invalidParams }
        let client = try await Memos.create(host: url, accessToken: accessToken, openId: nil)
        let response = try await client.me()
        await memosManager.reset(memosHost: url, accessToken: accessToken, openId: nil)
        currentUser = response
    }
    
    func signIn(memosHost: String, openId: String) async throws {
        guard let url = URL(string: memosHost) else { throw MemosError.invalidParams }
        let client = try await Memos.create(host: url, accessToken: nil, openId: openId)
        let response = try await client.me()
        await memosManager.reset(memosHost: url, accessToken: nil, openId: openId)
        currentUser = response
    }
    
    func logout() async throws {
        try await memos.logout()
        currentUser = nil
        UserDefaults(suiteName: groupContainerIdentifier)?.removeObject(forKey: memosOpenIdKey)
    }
}
