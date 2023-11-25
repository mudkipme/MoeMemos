//
//  Account.swift
//  
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import Models
import KeychainSwift
import MemosService

public extension Account {
    private static var keychain: KeychainSwift {
        let keychain = KeychainSwift()
        keychain.accessGroup = AppInfo.keychainAccessGroupName
        return keychain
    }
    
    func save() throws {
        let data = try JSONEncoder().encode(self)
        Self.keychain.set(data, forKey: key, withAccess: .accessibleAfterFirstUnlock)
    }
    
    func delete() {
        Self.keychain.delete(key)
    }
    
    static func retriveAll() -> [Account] {
        let keychain = Self.keychain
        let decoder = JSONDecoder()
        let keys = keychain.allKeys
        var accounts = [Account]()
        
        for key in keys {
            if let data = keychain.getData(key), let account = try? decoder.decode(Account.self, from: data) {
                accounts.append(account)
            }
        }
        return accounts
    }
    
    var memosService: MemosService? {
        if case .memos(host: let host, id: _, accessToken: let accessToken) = self, let hostURL = URL(string: host) {
            return MemosService(hostURL: hostURL, accessToken: accessToken)
        }
        return nil
    }
    
    @MainActor
    func toUser() async throws -> User {
        if case .local = self {
            return User(accountKey: key, nickname: NSLocalizedString("account.local-user", comment: ""))
        }
        if let memosService = memosService {
            let memosUser = try await memosService.getCurrentUser()
            let user = User(accountKey: key, nickname: memosUser.nickname ?? memosUser.username ?? "", defaultVisibility: .init(memosUser.defaultMemoVisibility))
            if let avatarUrl = memosUser.avatarUrl, let url = URL(string: avatarUrl) {
                user.avatarData = try? await memosService.downloadData(url: url)
            }
            return user
        }
        throw MemosServiceError.notLogin
    }
}
