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
    private static let maxUploadSizeBytes: Int64 = 1_073_741_824
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

    public func upload(data: Data, filename: String, mimeType: String) async throws {
        try validateUploadSize(Int64(data.count))
        let safeFilename = filename.isEmpty ? "\(UUID().uuidString).dat" : filename
        let response = try await service.createResource(filename: safeFilename, data: data, type: mimeType, memoRemoteId: nil)
        resourceList.append(response)
    }

    public func upload(fileURL: URL) async throws {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey, .nameKey, .fileSizeKey])
        if let fileSize = resourceValues?.fileSize {
            try validateUploadSize(Int64(fileSize))
        }
        let filename = resourceValues?.name ?? fileURL.lastPathComponent
        let mimeType = resourceValues?.contentType?.preferredMIMEType ?? "application/octet-stream"
        let data = try Data(contentsOf: fileURL)
        try await upload(data: data, filename: filename, mimeType: mimeType)
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

    private func validateUploadSize(_ size: Int64) throws {
        if size > Self.maxUploadSizeBytes {
            throw MoeMemosError.fileTooLarge(Self.maxUploadSizeBytes)
        }
    }
}
