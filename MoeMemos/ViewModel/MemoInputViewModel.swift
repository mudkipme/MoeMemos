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
class MemoInputViewModel: ObservableObject, ResourceManager {
    @Injected(\.accountManager) private var accountManager
    
    var memos: MemosService { get throws { try accountManager.mustCurrentService } }
    
    @Published var resourceList = [MemosResource]()
    @Published var imageUploading = false
    @Published var saving = false
    @Published var visibility: MemoVisibility = .private

    private var anyPhotos: Any?
    @available(iOS 16, *) var photos: [PhotosPickerItem]? {
        get { return anyPhotos as? [PhotosPickerItem] }
        set {
            objectWillChange.send()
            anyPhotos = newValue
        }
    }

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
