//
//  ResourceListViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/2.
//

import Foundation

@MainActor
class ResourceListViewModel: ObservableObject, ResourceManager {
    let memosManager: MemosManager
    init(memosManager: MemosManager = .shared) {
        self.memosManager = memosManager
    }
    var memos: Memos { get throws { try memosManager.api } }

    @Published private(set) var resourceList: [Resource] = []
    
    func loadResources() async throws {
        let response = try await memos.listResources()
        resourceList = response.data.filter({ resource in
            resource.type.hasPrefix("image/")
        })
    }
    
    func deleteResource(id: Int) async throws {
        _ = try await memos.deleteResource(id: id)
        resourceList = resourceList.filter({ resource in
            resource.id != id
        })
    }
}
