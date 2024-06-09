//
//  RemoteService.swift
//
//
//  Created by Mudkip on 2024/2/19.
//

import Foundation
import Models

extension MemosV0Service: RemoteService {
    public func fetchMemos() async throws -> [Memo] {
        return []
    }
    
    public func memoVisibilities() -> [MemoVisibility] {
        return [.private, .local, .public]
    }
}
