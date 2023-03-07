//
//  MemosViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

@MainActor
class MemosViewModel: ObservableObject {
    let memosManager: MemosManager
    init(memosManager: MemosManager = .shared) {
        self.memosManager = memosManager
    }
    var memos: Memos { get throws { try memosManager.api } }

    @Published private(set) var memoList: [Memo] = [] {
        didSet {
            matrix = DailyUsageStat.calculateMatrix(memoList: memoList)
        }
    }
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var matrix: [DailyUsageStat] = DailyUsageStat.initialMatrix
    @Published private(set) var inited = false
    @Published private(set) var loading = false
    
    func loadMemos() async throws {
        do {
            loading = true
            let response = try await memos.listMemos(data: MemosListMemo.Input(creatorId: nil, rowStatus: .normal, visibility: nil))
            memoList = response.data
            loading = false
            inited = true
        } catch {
            loading = false
            throw error
        }
    }
    
    func loadTags() async throws {
        let response = try await memos.tags(data: nil)
        tags = response.data.map({ name in
            Tag(name: name)
        })
    }
    
    func createMemo(content: String, visibility: MemosVisibility = .private, resourceIdList: [Int]? = nil) async throws {
        let response = try await memos.createMemo(data: MemosCreate.Input(content: content, visibility: visibility, resourceIdList: resourceIdList))
        memoList.insert(response.data, at: 0)
        try await loadTags()
    }
    
    private func updateMemo(_ memo: Memo) {
        for (i, item) in memoList.enumerated() {
            if item.id == memo.id {
                memoList[i] = memo
                break
            }
        }
    }
    
    func updateMemoOrganizer(id: Int, pinned: Bool) async throws {
        let response = try await memos.updateMemoOrganizer(memoId: id, data: MemosOrganizer.Input(pinned: pinned))
        // the response might be incorrect
        var memo = response.data
        memo.pinned = pinned
        
        updateMemo(memo)
    }
    
    func archiveMemo(id: Int) async throws {
        _ = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: .archived, content: nil, visibility: nil, resourceIdList: nil))
        memoList = memoList.filter({ memo in
            memo.id != id
        })
    }
    
    func editMemo(id: Int, content: String, visibility: MemosVisibility = .private, resourceIdList: [Int]? = nil) async throws {
        let response = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: nil, content: content, visibility: visibility, resourceIdList: resourceIdList))
        updateMemo(response.data)
        try await loadTags()
    }
}
