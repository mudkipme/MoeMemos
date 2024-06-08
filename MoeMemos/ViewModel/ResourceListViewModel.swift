//
//  ResourceListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation
import Account
import MemosService
import Factory

@Observable class ResourceListViewModel: ResourceManager {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var memos: MemosService { get throws { try accountManager.mustCurrentService } }

    private(set) var resourceList: [MemosResource] = []
    
    @MainActor
    func loadResources() async throws {
        let response = try await memos.listResources()
        resourceList = response.filter({ resource in
            resource._type?.hasPrefix("image/") ?? false
        })
    }
    
    @MainActor
    func deleteResource(id: Int) async throws {
        _ = try await memos.deleteResource(id: id)
        resourceList = resourceList.filter({ resource in
            resource.id != id
        })
    }
}
