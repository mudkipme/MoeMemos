//
//  ArchivedMemoListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation
import Account
import MemosService
import Factory

@MainActor
class ArchivedMemoListViewModel: ObservableObject {
    @Injected(\.accountManager) private var accountManager
    
    var memos: MemosService { get throws { try accountManager.mustCurrentService } }

    @Published private(set) var archivedMemoList: [MemosMemo] = []
    
    func loadArchivedMemos() async throws {
        let response = try await memos.listMemos(input: .init(rowStatus: .ARCHIVED))
        archivedMemoList = response
    }
    
    func restoreMemo(id: Int) async throws {
        _ = try await memos.updateMemo(id: id, input: .init(rowStatus: .NORMAL))
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
