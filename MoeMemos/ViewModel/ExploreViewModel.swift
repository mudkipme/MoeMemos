//
//  ExploreViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import Foundation
import Account
import MemosService
import Factory

@Observable class ExploreViewModel {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var memos: MemosService { get throws { try accountManager.mustCurrentService } }

    private(set) var memoList: [MemosMemo] = []
    private(set) var loading = false
    private(set) var hasMore = false
    
    @MainActor
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
    
    @MainActor
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
