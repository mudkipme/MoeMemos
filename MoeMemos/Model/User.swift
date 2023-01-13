//
//  User.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

struct MemosUserSetting: Decodable {
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
