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
            matrix = calculateMatrix()
        }
    }
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var matrix: [DailyUsageStat] = DailyUsageStat.initialMatrix
    @Published private(set) var archivedMemoList: [Memo] = []
    @Published private(set) var resourceList: [Resource] = []
    @Published private(set) var inited = false
    @Published private(set) var loading = false
    
    private func calculateMatrix() -> [DailyUsageStat] {
        var result = DailyUsageStat.initialMatrix
        var countDict = [String: Int]()
        
        for memo in memoList {
            let key = memo.createdTs.formatted(date: .numeric, time: .omitted)
            countDict[key] = (countDict[key] ?? 0) + 1
        }
        
        for (i, day) in result.enumerated() {
            result[i].count = countDict[day.id] ?? 0
        }
        
        return result
    }
    
    func loadMemos() async throws {
        do {
            loading = true
            let response = try await memos.listMemos(data: nil)
            memoList = response.data.filter({ memo in
                memo.rowStatus != .archived
            })
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
    
    func createMemo(content: String) async throws {
        let response = try await memos.createMemo(data: MemosCreate.Input(content: content, visibility: nil))
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
    
    func loadArchivedMemos() async throws {
        let response = try await memos.listMemos(data: MemosListMemo.Input(creatorId: nil, rowStatus: .archived, visibility: nil))
        archivedMemoList = response.data
    }
    
    func updateMemoOrganizer(id: Int, pinned: Bool) async throws {
        let response = try await memos.updateMemoOrganizer(memoId: id, data: MemosOrganizer.Input(pinned: pinned))
        // the response might be incorrect
        var memo = response.data
        memo.pinned = pinned
        
        updateMemo(memo)
    }
    
    func archiveMemo(id: Int) async throws {
        _ = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: .archived, content: nil, visibility: nil))
        memoList = memoList.filter({ memo in
            memo.id != id
        })
    }
    
    func restoreMemo(id: Int) async throws {
        _ = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: .normal, content: nil, visibility: nil))
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
        try await loadMemos()
    }
    
    func editMemo(id: Int, content: String) async throws {
        let response = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: nil, content: content, visibility: nil))
        updateMemo(response.data)
        try await loadTags()
    }
    
    func deleteMemo(id: Int) async throws {
        _ = try await memos.deleteMemo(id: id)
        memoList = memoList.filter({ memo in
            memo.id != id
        })
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
    }
    
    func loadResources() async throws {
        let response = try await memos.listResources()
        resourceList = response.data.filter({ resource in
            resource.type.hasPrefix("image/")
        })
    }
        
    func deleteResource(id: Int) async throws {
        _ = try await memos.deleteResource(id: id)
        resourceList = resourceList.filter({ resource in
            resource.id != id
        })
    }
}
