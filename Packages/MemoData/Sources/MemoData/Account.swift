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

public extension Account {
    private static var keychain: KeychainSwift {
        let keychain = KeychainSwift()
        keychain.accessGroup = AppInfo.keychainAccessGroupName
        return keychain
    }
    
    func save() throws {
        let data = try JSONEncoder().encode(self)
        let didSave = Self.keychain.set(data, forKey: key, withAccess: .accessibleAfterFirstUnlock)
        if !didSave {
            throw MoeMemosError.accountCredentialSaveFailed(accountKey: key)
        }
    }
    
    func delete() {
        Self.keychain.delete(key)
    }
    
    static func retrieve(accountKey: String) -> Account? {
        if accountKey == Account.local.key {
            return .local
        }
        guard let data = Self.keychain.getData(accountKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Account.self, from: data)
    }
    
    func remoteService() -> RemoteService? {
        if case .memosV0(host: let host, id: _, accessToken: let accessToken) = self, let hostURL = URL(string: host) {
            return MemosV0Service(hostURL: hostURL, accessToken: accessToken)
        }
        if case .memosV1(host: let host, id: let userId, accessToken: let accessToken) = self, let hostURL = URL(string: host) {
            return MemosV1Service(hostURL: hostURL, accessToken: accessToken, userId: userId)
        }
        return nil
    }
    
    @MainActor
    func toUser() async throws -> User {
        if case .local = self {
            return UserSnapshot.local(accountKey: key).toUserModel()
        }
        if let remoteService = remoteService() {
            let snapshot = try await remoteService.getCurrentUser()
            return snapshot.toUserModel()
        }
        throw MoeMemosError.notLogin
    }
}
