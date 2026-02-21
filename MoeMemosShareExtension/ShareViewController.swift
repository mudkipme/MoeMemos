//
//  ShareViewController.swift
//  MoeMemosShareExtension
//
//  Created by Mudkip on 2022/12/1.
//

@preconcurrency import UIKit
import Social
import SwiftUI
import KeychainSwift
import Models
import SwiftData
import Account
import UniformTypeIdentifiers
import MemoKit

class ShareViewController: SLComposeServiceViewController {
    private static let maxUploadSizeBytes: Int64 = 1_073_741_824
    let shareViewHostingController = UIHostingController(rootView: MoeMemosShareView())
    
    override func isContentValid() -> Bool {
        for attachment in inputAttachments {
            if isSupportedAttachment(attachment) {
                return true
            }
        }
        
        return !contentText.isEmpty
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        Task {
            do {
                shareViewHostingController.view.translatesAutoresizingMaskIntoConstraints = false
                self.addChild(shareViewHostingController)
                self.view.addSubview(shareViewHostingController.view)
                NSLayoutConstraint.activate([
                    shareViewHostingController.view.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                    shareViewHostingController.view.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
                ])
                try await handleShare()
                
                self.shareViewHostingController.rootView = MoeMemosShareView(alertType: .systemImage("checkmark.circle", NSLocalizedString("share.memo-saved", comment: "")))
                try await Task.sleep(nanoseconds: 2_000_000_000)
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            } catch {
                self.shareViewHostingController.rootView = MoeMemosShareView(alertType: .systemImage("xmark.circle", error.localizedDescription))
                try await Task.sleep(nanoseconds: 2_000_000_000)
                self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    private func handleShare() async throws {
        let accountManager = await MainActor.run { AccountManager(modelContext: AppInfo().modelContext) }
        let memos = await MainActor.run { accountManager.currentService }
        guard let memos else { throw MoeMemosError.notLogin }
        var resourceIds: [PersistentIdentifier] = []
        var contentTextList = [String]()
        contentTextList.append(contentText)
        
        for attachment in inputAttachments {
            if let resourceId = try await handleImageAttachment(attachment, memos: memos) {
                resourceIds.append(resourceId)
                continue
            }

            if let resourceId = try await handleFileAttachment(attachment, memos: memos) {
                resourceIds.append(resourceId)
                continue
            }

            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let url = try await attachment.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                if url.isFileURL {
                    resourceIds.append(try await uploadFile(at: url, typeIdentifier: nil, suggestedName: attachment.suggestedName, memos: memos))
                } else {
                    contentTextList.append(url.absoluteString)
                }
            }
        }
        
        let content = contentTextList.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
        if content.isEmpty && resourceIds.isEmpty {
            throw MoeMemosError.invalidParams
        }
        let tags = extractCustomTags(from: content)
        _ = try await memos.createMemo(content: content, visibility: nil, resources: resourceIds, tags: tags)

        // Share extensions are short-lived. Wait for queued remote operations so
        // this post does not stay local-only until the main app opens.
        if let pendingService = memos as? PendingOperationsService {
            await pendingService.waitForPendingOperations()
        }
    }
    
    private func extractCustomTags(from markdownText: String) -> [String] {
        MemoTagExtractor.extract(from: markdownText)
    }

    private var inputAttachments: [NSItemProvider] {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return []
        }
        return extensionItems.flatMap { $0.attachments ?? [] }
    }

    private func isSupportedAttachment(_ attachment: NSItemProvider) -> Bool {
        if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return true
        }
        if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            return true
        }
        if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return true
        }
        if attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            return true
        }
        return false
    }

    private func handleFileAttachment(_ attachment: NSItemProvider, memos: Service) async throws -> PersistentIdentifier? {
        if attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let fileURL = try await attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? URL {
            return try await uploadFile(at: fileURL, typeIdentifier: nil, suggestedName: attachment.suggestedName, memos: memos)
        }

        guard attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) else {
            return nil
        }

        guard let typeIdentifier = attachment.registeredTypeIdentifiers.first(where: {
            guard let type = UTType($0) else { return false }
            return type.conforms(to: .data) && !type.conforms(to: .url)
        }) else {
            return nil
        }

        let result = try await attachment.loadItem(forTypeIdentifier: typeIdentifier)
        if let fileURL = result as? URL {
            guard fileURL.isFileURL else {
                return nil
            }
            return try await uploadFile(at: fileURL, typeIdentifier: typeIdentifier, suggestedName: attachment.suggestedName, memos: memos)
        }
        if let data = result as? Data {
            return try await uploadData(data, typeIdentifier: typeIdentifier, suggestedName: attachment.suggestedName, memos: memos)
        }
        return nil
    }

    private func handleImageAttachment(_ attachment: NSItemProvider, memos: Service) async throws -> PersistentIdentifier? {
        guard attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }

        let typeIdentifier = attachment.registeredTypeIdentifiers.first(where: {
            guard let type = UTType($0) else { return false }
            return type.conforms(to: .image)
        }) ?? UTType.image.identifier

        if let imageData = try await attachment.loadDataRepresentationAsync(forTypeIdentifier: typeIdentifier) {
            return try await uploadData(imageData, typeIdentifier: typeIdentifier, suggestedName: attachment.suggestedName, memos: memos)
        }

        let result = try await attachment.loadItem(forTypeIdentifier: typeIdentifier)
        if let fileURL = result as? URL, fileURL.isFileURL {
            return try await uploadFile(at: fileURL, typeIdentifier: typeIdentifier, suggestedName: attachment.suggestedName, memos: memos)
        }
        if let data = result as? Data {
            return try await uploadData(data, typeIdentifier: typeIdentifier, suggestedName: attachment.suggestedName, memos: memos)
        }
        if let image = result as? UIImage, let data = image.pngData() {
            return try await uploadData(data, typeIdentifier: UTType.png.identifier, suggestedName: attachment.suggestedName, memos: memos)
        }
        throw MoeMemosError.invalidParams
    }

    private func uploadFile(at fileURL: URL, typeIdentifier: String?, suggestedName: String?, memos: Service) async throws -> PersistentIdentifier {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let values = try? fileURL.resourceValues(forKeys: [.nameKey, .contentTypeKey, .fileSizeKey])
        if let fileSize = values?.fileSize {
            try validateUploadSize(Int64(fileSize))
        }
        let contentType = values?.contentType ?? typeIdentifier.flatMap(UTType.init)
        let data = try Data(contentsOf: fileURL)
        try validateUploadSize(Int64(data.count))
        let filename = resolveFilename(baseName: values?.name ?? fileURL.lastPathComponent, fallbackName: suggestedName, contentType: contentType)
        let mimeType = contentType?.preferredMIMEType ?? "application/octet-stream"
        let response = try await memos.createResource(filename: filename, data: data, type: mimeType, memoId: nil)
        return response.id
    }

    private func uploadData(_ data: Data, typeIdentifier: String?, suggestedName: String?, memos: Service) async throws -> PersistentIdentifier {
        try validateUploadSize(Int64(data.count))
        let contentType = typeIdentifier.flatMap(UTType.init)
        let filename = resolveFilename(baseName: suggestedName, fallbackName: nil, contentType: contentType)
        let mimeType = contentType?.preferredMIMEType ?? "application/octet-stream"
        let response = try await memos.createResource(filename: filename, data: data, type: mimeType, memoId: nil)
        return response.id
    }

    private func resolveFilename(baseName: String?, fallbackName: String?, contentType: UTType?) -> String {
        let candidates = [baseName, fallbackName].compactMap {
            $0?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        let raw = candidates.first ?? UUID().uuidString
        let ext = URL(fileURLWithPath: raw).pathExtension
        if ext.isEmpty, let preferredExt = contentType?.preferredFilenameExtension {
            return "\(raw).\(preferredExt)"
        }
        return raw
    }

    private func validateUploadSize(_ size: Int64) throws {
        if size > Self.maxUploadSizeBytes {
            throw MoeMemosError.fileTooLarge(Self.maxUploadSizeBytes)
        }
    }
}

extension NSItemProvider: @unchecked @retroactive Sendable {}

private extension NSItemProvider {
    func loadDataRepresentationAsync(forTypeIdentifier typeIdentifier: String) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            self.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }
}
