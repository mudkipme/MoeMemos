//
//  MemosManager.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/1.
//

import Foundation

@MainActor
class MemosManager: ObservableObject {
    static let shared = MemosManager()
    
    @Published private(set) var memos: Memos?
    var hostURL: URL? {
        memos?.host
    }
    
    var api: Memos {
        get throws {
            guard let memos = memos else { throw MemosError.notLogin }
            return memos
        }
    }
    
    func reset(memosHost: URL, openId: String?) async {
        memos = Memos(host: memosHost, openId: openId)
        do {
            try await memos?.loadStatus()
        } catch {
            print(error)
        }
    }
    
    func reset(memosHost: String, openId: String?) async throws {
        if memosHost == "" {
            throw MemosError.notLogin
        }
        
        guard let url = URL(string: memosHost) else {
            throw MemosError.notLogin
        }
        
        await reset(memosHost: url, openId: openId)
    }
}
