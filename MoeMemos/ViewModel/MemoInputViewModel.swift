//
//  MemoInputViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/1.
//

import Foundation
import UIKit
import PhotosUI
import SwiftUI
import Markdown
import Account
import Models
import Factory

@MainActor
@Observable class MemoInputViewModel: ResourceManager {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var service: RemoteService { get throws { try accountManager.mustCurrentService } }
    
    var resourceList = [Resource]()
    var imageUploading = false
    var saving = false
    var visibility: MemoVisibility = .private
    var photos: [PhotosPickerItem] = []

    func upload(image: UIImage) async throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw MoeMemosError.invalidParams }
        let response = try await service.createResource(filename: "\(UUID().uuidString).jpg", data: data, type: "image/jpeg", memoRemoteId: nil)
        resourceList.append(response)
    }
    
    func deleteResource(remoteId: String) async throws {
        _ = try await service.deleteResource(remoteId: remoteId)
        resourceList = resourceList.filter({ resource in
            resource.remoteId != remoteId
        })
    }
    
    func extractCustomTags(from markdownText: String) -> [String] {
        let document = Document(parsing: markdownText)
        var tagVisitor = TagVisitor()
        document.accept(&tagVisitor)
        return tagVisitor.tags
    }
}
