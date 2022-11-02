//
//  ArchivedMemoListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation

@MainActor
class ArchivedMemoListViewModel: ObservableObject {
    let memosManager: MemosManager
    init(memosManager: MemosManager = .shared) {
        self.memosManager = memosManager
    }
    var memos: Memos { get throws { try memosManager.api } }

    @Published private(set) var archivedMemoList: [Memo] = []
    
    func loadArchivedMemos() async throws {
        let response = try await memos.listMemos(data: MemosListMemo.Input(creatorId: nil, rowStatus: .archived, visibility: nil))
        archivedMemoList = response.data
    }
    
    func restoreMemo(id: Int) async throws {
        _ = try await memos.updateMemo(data: MemosPatch.Input(id: id, createdTs: nil, rowStatus: .normal, content: nil, visibility: nil, resourceIdList: nil))
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
    }
    
    func deleteMemo(id: Int) async throws {
        _ = try await memos.deleteMemo(id: id)
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
    }
}
