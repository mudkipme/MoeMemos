//
//  ExploreViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import Foundation
import Account
import MemosService

@MainActor
class ExploreViewModel: ObservableObject {
    var memos: MemosService { get throws { try AccountManager.shared.mustCurrentService } }

    @Published private(set) var memoList: [MemosMemo] = []
    @Published private(set) var loading = false
    @Published private(set) var hasMore = false
    private var currentOffset = 0
    
    func loadMemos() async throws {
        do {
            loading = true
            let response = try await memos.listPublicMemos(limit: 20, offset: 0)
            memoList = response
            loading = false
            hasMore = response.count >= 20
        } catch {
            loading = false
            throw error
        }
    }
    
    func loadMoreMemos() async throws {
        guard !loading && hasMore else { return }
        do {
            loading = true
            let response = try await memos.listPublicMemos(limit: 20, offset: memoList.count)
            memoList += response
            loading = false
            hasMore = response.count >= 20
        } catch {
            loading = false
            throw error
        }
    }
}
