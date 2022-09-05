//
//  User.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

enum MemosRole: String, Decodable {
    case host = "HOST"
    case user = "USER"
}

enum MemosUserSettingKey: String, Decodable {
    case locale
    case memoVisibility
    case editorFontStyle
}

struct MemosUserSetting: Decodable {
    let key: MemosUserSettingKey
    let value: String
}

struct MemosUser: Decodable {
    let createdTs: Date
    let email: String
    let id: Int
    let name: String
    let openId: String
    let role: MemosRole
    let rowStatus: MemosRowStatus
    let updatedTs: Date
    let userSettingList: [MemosUserSetting]?
}
