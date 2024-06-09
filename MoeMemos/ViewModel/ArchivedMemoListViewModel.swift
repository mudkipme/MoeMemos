//
//  ArchivedMemoListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation
import Account
import MemosV0Service
import Factory

@Observable class ArchivedMemoListViewModel {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var memos: MemosV0Service { get throws { try accountManager.mustCurrentService } }

    private(set) var archivedMemoList: [MemosMemo] = []
    
    @MainActor
    func loadArchivedMemos() async throws {
        let response = try await memos.listMemos(input: .init(rowStatus: .ARCHIVED))
        archivedMemoList = response
    }
    
    @MainActor
    func restoreMemo(id: Int) async throws {
        _ = try await memos.updateMemo(id: id, input: .init(rowStatus: .NORMAL))
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
    }
    
    @MainActor
    func deleteMemo(id: Int) async throws {
        _ = try await memos.deleteMemo(id: id)
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
    }
}
