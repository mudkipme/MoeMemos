import Foundation
import UIKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
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

    public func upload(fileURL: URL) async throws {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey, .nameKey])
        let filename = resourceValues?.name ?? fileURL.lastPathComponent
        let mimeType = resourceValues?.contentType?.preferredMIMEType ?? "application/octet-stream"
        let data = try Data(contentsOf: fileURL)
        let response = try await service.createResource(
            filename: filename.isEmpty ? "\(UUID().uuidString).dat" : filename,
            data: data,
            type: mimeType,
            memoRemoteId: nil
        )
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
