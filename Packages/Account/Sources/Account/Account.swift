//
//  Account.swift
//  
//
//  Created by Mudkip on 2023/11/12.
//

import Foundation
import Models
import KeychainSwift
import MemosV0Service
import MemosV1Service
import BlinkoV1Service

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
    
    func remoteService() -> RemoteService? {
        if case .memosV0(let host, _, let accessToken) = self, let hostURL = URL(string: host) {
            return MemosV0Service(hostURL: hostURL, accessToken: accessToken)
        }
        if case .memosV1(let host, let userId, let accessToken) = self, let hostURL = URL(string: host) {
            return MemosV1Service(hostURL: hostURL, accessToken: accessToken, userId: userId)
        }
        if case .blinkoV1(let host, _, let accessToken) = self, let hostURL = URL(string: host) {
            return BlinkoV1Service(hostURL: hostURL, accessToken: accessToken)
        }
        return nil
    }
    
    @MainActor
    func toUser() async throws -> User {
        if case .local = self {
            return User(accountKey: key, nickname: NSLocalizedString("account.local-user", comment: ""))
        }
        if let remoteService = remoteService() {
            return try await remoteService.getCurrentUser()
        }
        throw MoeMemosError.notLogin
    }
}
