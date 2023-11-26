//
//  File.swift
//  
//
//  Created by Mudkip on 2023/11/19.
//

import Foundation

public protocol RemoteService {
    func fetchMemos() async throws -> [Memo]
}
