//
//  MemosViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation
import Account
import MemosService
import Models

@MainActor
class MemosViewModel: ObservableObject {
    var memos: MemosService { get throws { try AccountManager.shared.mustCurrentService } }

    @Published private(set) var memoList: [MemosMemo] = [] {
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
            let response = try await memos.listMemos(input: .init(rowStatus: .NORMAL))
            memoList = response
            loading = false
            inited = true
        } catch {
            loading = false
            throw error
        }
    }
    
    func loadTags() async throws {
        let response = try await memos.listTags()
        tags = response.map({ name in
            Tag(name: name)
        })
    }
    
    func createMemo(content: String, visibility: MemosVisibility = .PRIVATE, resourceIdList: [Int]? = nil) async throws {
        let response = try await memos.createMemo(input: .init(content: content, resourceIdList: resourceIdList, visibility: visibility))
        memoList.insert(response, at: 0)
        try await loadTags()
    }
    
    private func updateMemo(_ memo: MemosMemo) {
        for (i, item) in memoList.enumerated() {
            if item.id == memo.id {
                memoList[i] = memo
                break
            }
        }
    }
    
    func updateMemoOrganizer(id: Int, pinned: Bool) async throws {
        let response = try await memos.memoOrganizer(id: id, pinned: pinned)
        // the response might be incorrect
        var memo = response
        memo.pinned = pinned
        
        updateMemo(memo)
    }
    
    func archiveMemo(id: Int) async throws {
        _ = try await memos.updateMemo(id: id, input: .init(rowStatus: .ARCHIVED))
        memoList = memoList.filter({ memo in
            memo.id != id
        })
    }
    
    func editMemo(id: Int, content: String, visibility: MemosVisibility = .PRIVATE, resourceIdList: [Int]? = nil) async throws {
        let response = try await memos.updateMemo(id: id, input: .init(content: content, resourceIdList: resourceIdList, visibility: visibility))
        updateMemo(response)
        try await loadTags()
    }
    
    func upsertTags(names: [String]) async throws {
        for name in names {
            _ = try await memos.upsertTag(name: name)
        }
        
        try await loadTags()
    }
    
    func deleteTag(name: String) async throws {
        _ = try await memos.deleteTag(name: name)
        
        tags.removeAll { tag in
            tag.name == name
        }
    }

    func deleteMemo(id: Int) async throws {
        _ = try await memos.deleteMemo(id: id)
        memoList = memoList.filter({ memo in
            memo.id != id
        })
    }
}
