//
//  ArchivedMemoListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import MemoData
import Foundation
import Factory
import Models
import SwiftData

@MainActor
@Observable class ArchivedMemoListViewModel {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    @Injected(\.memosViewModel) private var memosViewModel
    @ObservationIgnored
    var service: Service { get throws { try accountManager.mustCurrentService } }

    private(set) var archivedMemoList: [StoredMemo] = []
    
    @MainActor
    func loadArchivedMemos() async throws {
        try await reloadArchivedMemos()
        let service = try self.service
        if service is SyncableService {
            startBackgroundSync()
        }
    }

    @MainActor
    func reloadArchivedMemos() async throws {
        let accountKey = accountManager.currentAccount?.key
        let service = try self.service
        let loaded = try await service.listArchivedMemos()
        guard accountManager.currentAccount?.key == accountKey else { return }
        archivedMemoList = loaded
        memosViewModel.refreshSyncStatus()
    }
    
    @MainActor
    func restoreMemo(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.restoreMemo(id: id)
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
        memosViewModel.refreshSyncStatus()
    }
    
    @MainActor
    func deleteMemo(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.deleteMemo(id: id)
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
        memosViewModel.refreshSyncStatus()
    }
    
    @MainActor
    private func startBackgroundSync() {
        let accountKey = accountManager.currentAccount?.key
        guard BackgroundSyncThrottle.canStartSync(for: accountKey) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.memosViewModel.syncNow(trigger: .automatic)
                guard self.accountManager.currentAccount?.key == accountKey else { return }
                let service = try self.service
                let loaded = try await service.listArchivedMemos()
                guard self.accountManager.currentAccount?.key == accountKey else { return }
                self.archivedMemoList = loaded
            } catch {
                // Keep the current list when background sync fails.
                return
            }
        }
    }
}
