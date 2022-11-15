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
    
    func reset(memosHost: String, openId: String?) throws {
        try memosManager.reset(memosHost: memosHost, openId: openId)
        currentUser = nil
    }
    
    func loadCurrentUser() async throws {
        let response = try await memos.me()
        currentUser = response.data
    }
    
    func signIn(memosHost: String, input: MemosSignIn.Input) async throws {
        guard let url = URL(string: memosHost) else { throw MemosError.invalidParams }
        
        let client = Memos(host: url, openId: nil)
        let response = try await client.signIn(data: input)
        memosManager.reset(memosHost: url, openId: nil)
        currentUser = response.data
    }
    
    func signIn(memosOpenAPI: String) async throws {
        guard let url = URL(string: memosOpenAPI) else { throw MemosError.invalidParams }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw MemosError.invalidParams }
        guard let openId = components.queryItems?
            .first(where: { queryItem in queryItem.name == "openId" })?
            .value else { throw MemosError.invalidOpenAPI }
        
        components.path = ""
        components.query = nil
        components.fragment = nil
        
        let client = Memos(host: components.url!, openId: openId)
        let response = try await client.me()
        memosManager.reset(memosHost: components.url!, openId: openId)
        currentUser = response.data
    }
    
    func logout() async throws {
        try await memos.logout()
        currentUser = nil
        UserDefaults(suiteName: groupContainerIdentifier)?.removeObject(forKey: memosOpenIdKey)
    }
}
