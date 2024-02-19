//
//  File.swift
//  
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation

public protocol MoeMemosService {
    func memoVisibilities() -> [MemoVisibility]
}

public protocol RemoteService: MoeMemosService {
    func fetchMemos() async throws -> [Memo]
}
