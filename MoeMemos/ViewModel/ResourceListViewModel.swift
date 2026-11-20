//
//  ResourceListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import MemoData
import Foundation
import Models
import Factory
import MemoKit
import SwiftData

@MainActor
@Observable class ResourceListViewModel: ResourceManager {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    @Injected(\.memosViewModel) private var memosViewModel
    @ObservationIgnored
    var service: Service { get throws { try accountManager.mustCurrentService } }

    private(set) var resourceList: [StoredResource] = []
    
    @MainActor
    func loadResources() async throws {
        let accountKey = accountManager.currentAccount?.key
        let service = try self.service
        let loaded = try await service.listResources()
        guard accountManager.currentAccount?.key == accountKey else { return }
        resourceList = loaded.filter { $0.memo != nil && $0.memo?.softDeleted == false }
        memosViewModel.refreshSyncStatus()
        if service is SyncableService {
            startBackgroundSync()
        }
    }
    
    @MainActor
    func deleteResource(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.deleteResource(id: id)
        resourceList.removeAll { $0.id == id }
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
                let loaded = try await service.listResources()
                guard self.accountManager.currentAccount?.key == accountKey else { return }
                self.resourceList = loaded.filter { $0.memo != nil && $0.memo?.softDeleted == false }
            } catch {
                // Keep the current list when background sync fails.
                return
            }
        }
    }
}
