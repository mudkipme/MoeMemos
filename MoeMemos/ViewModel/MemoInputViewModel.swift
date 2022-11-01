//
//  MemoInputViewModel.swift
//  MoeMemos
//
//  Created by Mudkip on 2022/11/1.
//

import Foundation
import UIKit

@MainActor
class MemoInputViewModel: ObservableObject {
    let memosManager: MemosManager
    init(memosManager: MemosManager = .shared) {
        self.memosManager = memosManager
    }
    var memos: Memos { get throws { try memosManager.api } }

    func upload(image: UIImage) async throws -> Resource {
        var image = image
        if image.size.height > 1024 || image.size.width > 1024 {
            image = image.scale(to: CGSize(width: 1024, height: 1024))
        }
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw MemosError.invalidParams }
        let response = try await memos.uploadResource(imageData: data, filename: "\(UUID().uuidString).jpg", contentType: "image/jpeg")
        return response.data
    }
}
