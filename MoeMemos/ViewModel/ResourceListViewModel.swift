//
//  ResourceListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation
import Account
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
        let service = try self.service
        resourceList = try await service.listResources()
        resourceList = resourceList.filter { $0.memo != nil && $0.memo?.softDeleted == false }
        if service is SyncableService {
            startBackgroundSync()
        }
    }
    
    @MainActor
    func deleteResource(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.deleteResource(id: id)
        resourceList.removeAll { $0.id == id }
    }
    
    @MainActor
    private func startBackgroundSync() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.memosViewModel.syncNow()
                let service = try self.service
                self.resourceList = try await service.listResources()
                self.resourceList = self.resourceList.filter { $0.memo != nil && $0.memo?.softDeleted == false }
            } catch {
                // Keep the current list when background sync fails.
                return
            }
        }
    }
}
