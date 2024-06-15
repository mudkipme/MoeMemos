//
//  ArchivedMemoListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation
import Account
import Factory
import Models

@Observable class ArchivedMemoListViewModel {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var service: RemoteService { get throws { try accountManager.mustCurrentService } }

    private(set) var archivedMemoList: [Memo] = []
    
    @MainActor
    func loadArchivedMemos() async throws {
        let response = try await service.listArchivedMemos()
        archivedMemoList = response
    }
    
    @MainActor
    func restoreMemo(remoteId: String) async throws {
        _ = try await service.restoreMemo(remoteId: remoteId)
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.remoteId != remoteId
        })
    }
    
    @MainActor
    func deleteMemo(remoteId: String) async throws {
        _ = try await service.deleteMemo(remoteId: remoteId)
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.remoteId != remoteId
        })
    }
}
