import Foundation
import UIKit
import PhotosUI
import SwiftUI
import Markdown
import Account
import Models
import Factory

@MainActor
@Observable public class MemoEditorViewModel: ResourceManager {
    @ObservationIgnored
    @Injected(\.accountManager) private var accountManager
    @ObservationIgnored
    var service: RemoteService { get throws { try accountManager.mustCurrentService } }

    public var resourceList = [Resource]()
    public var imageUploading = false
    public var saving = false
    public var visibility: MemoVisibility = .private
    public var photos: [PhotosPickerItem] = []

    public init() {}

    public func upload(image: UIImage) async throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw MoeMemosError.invalidParams }
        let response = try await service.createResource(filename: "\(UUID().uuidString).jpg", data: data, type: "image/jpeg", memoRemoteId: nil)
        resourceList.append(response)
    }

    public func deleteResource(remoteId: String) async throws {
        _ = try await service.deleteResource(remoteId: remoteId)
        resourceList = resourceList.filter { resource in
            resource.remoteId != remoteId
        }
    }

    public func extractCustomTags(from markdownText: String) -> [String] {
        MemoTagExtractor.extract(from: markdownText)
    }
}
