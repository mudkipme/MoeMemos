//
//  APIBase.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation


struct MemosErrorOutput: Decodable {
    let error: String
    let message: String
}

fileprivate extension String {
    func replacingPrefix(_ prefix: String, with newPrefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return newPrefix + String(self.dropFirst(prefix.count))
    }
}
