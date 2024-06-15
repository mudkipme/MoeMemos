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

@Observable class ResourceListViewModel: ResourceManager {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var service: RemoteService { get throws { try accountManager.mustCurrentService } }

    private(set) var resourceList: [Resource] = []
    
    @MainActor
    func loadResources() async throws {
        let response = try await service.listResources()
        resourceList = response.filter({ resource in
            resource.mimeType.hasPrefix("image/")
        })
    }
    
    @MainActor
    func deleteResource(remoteId: String) async throws {
        _ = try await service.deleteResource(remoteId: remoteId)
        resourceList = resourceList.filter({ resource in
            resource.remoteId != remoteId
        })
    }
}
