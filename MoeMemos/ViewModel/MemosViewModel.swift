//
//  MemosViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/9/5.
//

import Foundation

@MainActor
class MemosViewModel: ObservableObject {
    private var memos: Memos?
    @Published private(set) var currentUser: MemosUser?
    @Published private(set) var memoList: [Memo] = [] {
        didSet {
            matrix = calculateMatrix()
        }
    }
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var matrix: [DailyUsageStat] = DailyUsageStat.initialMatrix
    @Published private(set) var archivedMemoList: [Memo] = []
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
    
    func reset(memosHost: String) throws {
        if memosHost == "" {
            throw MemosError.notLogin
        }
        
        guard let url = URL(string: memosHost) else {
            throw MemosError.notLogin
        }
        
        memos = Memos(host: url)
        currentUser = nil
    }
    
    func loadCurrentUser() async throws {
        guard let memos = memos else { throw MemosError.notLogin }
        
        let response = try await memos.me()
        currentUser = response.data
    }
    
    func signIn(memosHost: String, input: MemosSignIn.Input) async throws {
        guard let url = URL(string: memosHost) else { throw MemosError.invalidParams }
        
        let client = Memos(host: url)
        let response = try await client.signIn(data: input)
        memos = client
        currentUser = response.data
    }
    
    func logout() async throws {
        guard let memos = memos else { throw MemosError.notLogin }

        try await memos.logout()
        currentUser = nil
    }
    
    func loadMemos() async throws {
        guard let memos = memos else { throw MemosError.notLogin }
        
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
        guard let memos = memos else { throw MemosError.notLogin }
        
        let response = try await memos.tags(data: nil)
        tags = response.data.map({ name in
            Tag(name: name)
        })
    }
    
    func createMemo(content: String) async throws {
        guard let memos = memos else { throw MemosError.notLogin }

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
        guard let memos = memos else { throw MemosError.notLogin }
        
        let response = try await memos.listMemos(data: MemosListMemo.Input(creatorId: nil, rowStatus: .archived, visibility: nil))
        archivedMemoList = response.data
    }
    
    func updateMemoOrganizer(id: Int, pinned: Bool) async throws {
        guard let memos = memos else { throw MemosError.notLogin }
        
        let response = try await memos.updateMemoOrganizer(memoId: id, data: MemosOrganizer.Input(pinned: pinned))
        // the response might be incorrect
        var memo = response.data
        memo.pinned = pinned
        
        updateMemo(memo)
    }
    
    func archiveMemo(id: Int) async throws {
        guard let memos = memos else { throw MemosError.notLogin }

        _ = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: .archived, content: nil, visibility: nil))
        memoList = memoList.filter({ memo in
            memo.id != id
        })
    }
    
    func restoreMemo(id: Int) async throws {
        guard let memos = memos else { throw MemosError.notLogin }

        _ = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: .normal, content: nil, visibility: nil))
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
        try await loadMemos()
    }
    
    func editMemo(id: Int, content: String) async throws {
        guard let memos = memos else { throw MemosError.notLogin }

        let response = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: nil, content: content, visibility: nil))
        updateMemo(response.data)
        try await loadTags()
    }
    
    func deleteMemo(id: Int) async throws {
        guard let memos = memos else { throw MemosError.notLogin }
        _ = try await memos.deleteMemo(id: id)
        memoList = memoList.filter({ memo in
            memo.id != id
        })
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
    }
}
