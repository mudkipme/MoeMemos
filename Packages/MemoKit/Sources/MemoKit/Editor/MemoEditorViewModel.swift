import Foundation
import UIKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import MemoData
import Models
import Factory
import SwiftData

@MainActor
@Observable public class MemoEditorViewModel: ResourceManager {
    private static let maxUploadSizeBytes: Int64 = 1_073_741_824
    @ObservationIgnored
    private let accountManager: AccountManager
    @ObservationIgnored
    var accountKey: String?
    @ObservationIgnored
    var service: Service {
        get throws {
            if let accountKey, accountManager.currentAccount?.key != accountKey {
                throw MemoEditorError.accountChanged
            }
            return try accountManager.mustCurrentService
        }
    }

    public var resourceList = [StoredResource]()
    public var location: MemoLocation?
    public var supportsLocations: Bool { (try? service.supportsMemoLocations) == true }
    public var visibility: MemoVisibility = .private
    public var photos: [PhotosPickerItem] = []

    public init(accountManager: AccountManager? = nil) {
        self.accountManager = accountManager ?? Container.shared.accountManager()
    }

    public var removalLabel: String {
        NSLocalizedString("input.remove-attachment", comment: "Remove attachment from draft")
    }

    public func upload(data: Data, filename: String, mimeType: String) async throws {
        try validateUploadSize(Int64(data.count))
        let safeFilename = filename.isEmpty ? "\(UUID().uuidString).dat" : filename
        let service = try self.service
        let stored = try await service.createResource(filename: safeFilename, data: data, type: mimeType, memoId: nil)
        resourceList.append(stored)
    }

    public func upload(fileURL: URL) async throws {
        // Capture the editor account before any file preparation can suspend.
        let service = try self.service
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
        let data = try await Task.detached { try Data(contentsOf: fileURL) }.value
        try Task.checkCancellation()
        try validateUploadSize(Int64(data.count))
        let stored = try await service.createResource(filename: filename, data: data, type: mimeType, memoId: nil)
        resourceList.append(stored)
    }

    public func deleteResource(id: PersistentIdentifier) async throws {
        // Stage removal in the editor. Saving the memo commits its attachment list;
        // closing or discarding an edit must not delete the underlying resource.
        resourceList.removeAll { $0.id == id }
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
