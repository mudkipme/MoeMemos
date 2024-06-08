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
import MemosService
import Account
import Models
import Factory

@MainActor
@Observable class MemoInputViewModel: ResourceManager {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var memos: MemosService { get throws { try accountManager.mustCurrentService } }
    
    var resourceList = [MemosResource]()
    var imageUploading = false
    var saving = false
    var visibility: MemoVisibility = .private
    var photos: [PhotosPickerItem] = []

    func upload(image: UIImage) async throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw MemosServiceError.invalidParams }
        let response = try await memos.uploadResource(imageData: data, filename: "\(UUID().uuidString).jpg", contentType: "image/jpeg")
        resourceList.append(response)
    }
    
    func deleteResource(id: Int) async throws {
        _ = try await memos.deleteResource(id: id)
        resourceList = resourceList.filter({ resource in
            resource.id != id
        })
    }
    
    func extractCustomTags(from markdownText: String) -> [String] {
        let document = Document(parsing: markdownText)
        var tagVisitor = TagVisitor()
        document.accept(&tagVisitor)
        return tagVisitor.tags
    }
}
