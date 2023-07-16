//
//  ExploreViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2023/3/26.
//

import Foundation

@MainActor
class ExploreViewModel: ObservableObject {
    let memosManager: MemosManager
    init(memosManager: MemosManager = .shared) {
        self.memosManager = memosManager
    }
    var memos: Memos { get throws { try memosManager.api } }

    @Published private(set) var memoList: [Memo] = []
    @Published private(set) var loading = false
    @Published private(set) var hasMore = false
    private var currentOffset = 0
    
    func loadMemos() async throws {
        do {
            loading = true
            let response = try await memos.listAllMemo(data: MemosListAllMemo.Input(pinned: nil, tag: nil, visibility: nil, limit: 20, offset: nil))
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
            let response = try await memos.listAllMemo(data: MemosListAllMemo.Input(pinned: nil, tag: nil, visibility: nil, limit: 20, offset: memoList.count))
            memoList += response
            loading = false
            hasMore = response.count >= 20
        } catch {
            loading = false
            throw error
        }
    }
}
