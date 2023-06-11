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

@MainActor
class MemoInputViewModel: ObservableObject, ResourceManager {
    let memosManager: MemosManager
    init(memosManager: MemosManager = .shared) {
        self.memosManager = memosManager
    }
    var memos: Memos { get throws { try memosManager.api } }
    
    @Published var resourceList = [Resource]()
    @Published var imageUploading = false
    @Published var saving = false
    @Published var visibility: MemosVisibility = .private

    private var anyPhotos: Any?
    @available(iOS 16, *) var photos: [PhotosPickerItem]? {
        get { return anyPhotos as? [PhotosPickerItem] }
        set {
            objectWillChange.send()
            anyPhotos = newValue
        }
    }

    func upload(image: UIImage) async throws {
        var image = image
        if image.size.height > 1024 || image.size.width > 1024 {
            image = image.scale(to: CGSize(width: 1024, height: 1024))
        }
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw MemosError.invalidParams }
        let response = try await memos.uploadResource(imageData: data, filename: "\(UUID().uuidString).jpg", contentType: "image/jpeg")
        resourceList.append(response.data)
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
