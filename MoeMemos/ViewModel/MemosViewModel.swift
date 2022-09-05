//
//  MemosViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

@MainActor
class MemosViewModel: ObservableObject {
    private var memos: Memos?
    @Published private(set) var currentUser: MemosUser?
    
    func reset(memosHost: String) throws {
        if memosHost == "" {
            throw MemosError.notLogin
        }
        
        guard let url = URL(string: memosHost) else {
            throw MemosError.notLogin
        }
        
        memos = Memos(host: url)
        currentUser = nil
    }
    
    func loadCurrentUser() async throws {
        guard let memos = memos else { throw MemosError.notLogin }
        
        let response = try await memos.me()
        currentUser = response.data
    }
    
    func signIn(memosHost: String, input: MemosSignIn.Input) async throws {
        guard let url = URL(string: memosHost) else { throw MemosError.invalidParams }
        
        let client = Memos(host: url)
        let response = try await client.signIn(data: input)
        memos = client
        currentUser = response.data
    }
    
    func logout() async throws {
        guard let memos = memos else { throw MemosError.notLogin }

        try await memos.logout()
        currentUser = nil
    }
}
