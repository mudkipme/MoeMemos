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
    var service: Service { get throws { try accountManager.mustCurrentService } }

    private(set) var resourceList: [StoredResource] = []
    
    @MainActor
    func loadResources() async throws {
        let service = try self.service
        resourceList = try await service.listResources()
        if let syncService = service as? SyncableService {
            do {
                try await syncService.sync()
                resourceList = try await service.listResources()
            } catch {
                return
            }
        }
        resourceList = resourceList.filter { $0.mimeType.hasPrefix("image/") }
    }
    
    @MainActor
    func deleteResource(id: PersistentIdentifier) async throws {
        let service = try self.service
        try await service.deleteResource(id: id)
        resourceList.removeAll { $0.id == id }
    }
}
