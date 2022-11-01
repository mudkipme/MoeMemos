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
    
    @Published private(set) var currentUser: MemosUser?
    @Published var showingLogin = false
    
    func reset(memosHost: String) throws {
        try memosManager.reset(memosHost: memosHost)
        currentUser = nil
    }
    
    func loadCurrentUser() async throws {
        let response = try await memos.me()
        currentUser = response.data
    }
    
    func signIn(memosHost: String, input: MemosSignIn.Input) async throws {
        guard let url = URL(string: memosHost) else { throw MemosError.invalidParams }
        
        let client = Memos(host: url)
        let response = try await client.signIn(data: input)
        memosManager.reset(memosHost: url)
        currentUser = response.data
    }
    
    func logout() async throws {
        try await memos.logout()
        currentUser = nil
    }
}
