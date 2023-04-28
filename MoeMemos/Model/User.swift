//
//  User.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

struct MemosUserSetting: Decodable {
    static let memoVisibilityKey = "memo-visibility"
    let key: String
    let value: String
}

struct MemosUser: Decodable {
    let createdTs: Date
    let email: String?
    let username: String?
    let id: Int
    let name: String?
    let nickname: String?
    let openId: String
    let role: String
    let rowStatus: MemosRowStatus
    let updatedTs: Date
    let userSettingList: [MemosUserSetting]?
    
    var displayName: String {
        nickname ?? name ?? ""
    }
    
    var displayEmail: String {
        email ?? username ?? ""
    }
}

extension MemosUser {
    var defaultMemoVisibility: MemosVisibility {
        guard let visibilityJson = self.userSettingList?.first(where: { $0.key == MemosUserSetting.memoVisibilityKey })?.value.data(using: .utf8) else { return .private }
        do {
            return try JSONDecoder().decode(MemosVisibility.self, from: visibilityJson)
        } catch {
            return .private
        }
    }
}
