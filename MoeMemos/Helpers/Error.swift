//
//  Error.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

enum MemosError: Error {
    case unknown
    case notLogin
    case invalidStatusCode(Int)
    case invalidParams
}
