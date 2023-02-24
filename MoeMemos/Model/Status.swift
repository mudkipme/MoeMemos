//
//  Status.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/1/30.
//

import Foundation

struct MemosProfile: Decodable {
    let mode: String
    let version: String
}

struct MemosServerStatus: Decodable {
    let host: MemosUser
    let profile: MemosProfile
}
