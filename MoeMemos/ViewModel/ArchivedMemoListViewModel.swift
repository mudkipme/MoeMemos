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
        let service = try self.service
        archivedMemoList = try await service.listArchivedMemos()
    }
    
    @MainActor
    func restoreMemo(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.restoreMemo(id: id)
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
    }
    
    @MainActor
    func deleteMemo(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.deleteMemo(id: id)
        archivedMemoList = archivedMemoList.filter({ memo in
            memo.id != id
        })
    }
    
    @MainActor
    private func startBackgroundSync() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.memosViewModel.syncNow(trigger: .automatic)
                let service = try self.service
                self.archivedMemoList = try await service.listArchivedMemos()
            } catch {
                // Keep the current list when background sync fails.
                return
            }
        }
    }
}
