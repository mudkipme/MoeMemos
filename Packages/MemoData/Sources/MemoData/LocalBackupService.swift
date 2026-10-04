import Foundation
import Models
import SwiftData
import UniformTypeIdentifiers

public struct LocalImportPreview: Sendable {
    public let memos: Int
    public let attachments: Int
    public let existingMemos: Int
    public let legacy: Bool
    public let ignoredFiles: Int
}

public struct LocalImportResult: Sendable {
    public let importedMemos: Int
    public let skippedMemos: Int
    public let importedAttachments: Int
    public let skippedAttachments: Int
}

public final class PreparedLocalImport: Sendable {
    let directory: URL
    let data: LocalBackupData
    public let preview: LocalImportPreview

    init(directory: URL, data: LocalBackupData, existing: Set<String>) {
        self.directory = directory
        self.data = data
        self.preview = LocalImportPreview(memos: data.manifest.memos.count, attachments: data.manifest.attachments.count,
            existingMemos: data.manifest.memos.filter { existing.contains($0.id) }.count,
            legacy: data.legacy, ignoredFiles: data.ignoredFiles)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

/// All operations are serialized off the UI thread and always target the local
/// account, regardless of which account is selected while an operation runs.
public actor LocalBackupService {
    private let container: ModelContainer
    private let resourceDirectory: URL?
    private let accountKey = Account.local.key

    init(container: ModelContainer, resourceDirectory: URL? = nil) {
        self.container = container
        self.resourceDirectory = resourceDirectory
    }

    public func export() throws -> URL {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let allMemos = try memos(in: context)
        let allResources = try resources(in: context)
        // Include tombstones when allocating identities so a later restore never
        // resurrects an item that was already present and deliberately deleted.
        for memo in allMemos where memo.backupId == nil { memo.backupId = UUID().uuidString.lowercased() }
        for resource in allResources where resource.backupId == nil { resource.backupId = UUID().uuidString.lowercased() }
        try context.save()
        let memos = allMemos.filter { !$0.softDeleted }.sorted { $0.createdAt < $1.createdAt }
        let memoIds = Set(memos.compactMap(\.backupId))
        let resources = allResources.filter { resource in
            !resource.softDeleted && (resource.memo == nil || resource.memo?.backupId.map { memoIds.contains($0) } == true)
        }.sorted { $0.createdAt < $1.createdAt }
        let records = memos.enumerated().map { index, memo in
            LocalBackupMemo(id: memo.backupId!, contentFile: "memos/\(index).md",
                createdAt: LocalBackupArchive.timestamp(memo.createdAt), updatedAt: LocalBackupArchive.timestamp(memo.updatedAt),
                visibility: Self.visibility(memo.visibility), pinned: memo.pinned, archived: memo.rowStatus == .archived)
        }
        let attachments = resources.enumerated().map { index, resource in
            LocalBackupAttachment(id: resource.backupId!, memoId: resource.memo?.backupId, filename: resource.filename,
                mimeType: resource.mimeType, createdAt: LocalBackupArchive.timestamp(resource.createdAt), file: "attachments/\(index)")
        }
        var files: [String: URL] = [:]
        for (record, resource) in zip(attachments, resources) {
            let url = resource.localPath.map { URL(fileURLWithPath: $0) } ?? resource.url
            guard let url, url.isFileURL else { throw LocalBackupError("Missing local attachment: \(resource.filename)") }
            files[record.file] = url
        }
        let data = LocalBackupData(manifest: LocalBackupManifest(exportedAt: LocalBackupArchive.timestamp(.now), memos: records, attachments: attachments),
            contents: Dictionary(uniqueKeysWithValues: zip(records, memos).map { ($0.contentFile, $1.content) }), files: files)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("MoeMemos-Backup-\(UUID().uuidString).zip")
        try LocalBackupArchive.write(data, to: destination)
        return destination
    }

    public func prepareImport(from source: URL) throws -> PreparedLocalImport {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MoeMemos-Import-\(UUID().uuidString)")
        do {
            let data = try LocalBackupArchive.read(source, stagingDirectory: directory)
            let existing = Set(try memos(in: ModelContext(container)).compactMap(\.backupId))
            return PreparedLocalImport(directory: directory, data: data, existing: existing)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    public func restore(_ prepared: PreparedLocalImport) async throws -> LocalImportResult {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let existing = Set(try memos(in: context).compactMap(\.backupId))
        let existingResources = Set(try resources(in: context).compactMap(\.backupId))
        let data = prepared.data
        let pending = data.manifest.memos.filter { !existing.contains($0.id) }
        var inserted: [String: StoredMemo] = [:]
        var createdFiles: [URL] = []
        var committed = false
        defer {
            if !committed {
                context.rollback()
                for url in createdFiles { try? FileManager.default.removeItem(at: url) }
            }
        }
        // No suspension/cancellation during copying and commit: either every row
        // is saved or the private context and all newly-created files roll back.
        for memo in pending {
            let stored = StoredMemo(accountKey: accountKey, content: data.contents[memo.contentFile]!, pinned: memo.pinned,
                rowStatus: memo.archived ? .archived : .normal, visibility: Self.visibility(memo.visibility),
                createdAt: try LocalBackupArchive.date(memo.createdAt), updatedAt: try LocalBackupArchive.date(memo.updatedAt))
            stored.backupId = memo.id
            context.insert(stored)
            inserted[memo.id] = stored
        }
        var importedAttachments = 0
        for attachment in data.manifest.attachments {
            if let memoId = attachment.memoId, inserted[memoId] == nil { continue }
            // Resource identities are account-wide. Never overwrite an existing
            // attachment, including an unattached resource or a tombstone.
            if existingResources.contains(attachment.id) { continue }
            let mimeType = attachment.mimeType ?? UTType(filenameExtension: URL(fileURLWithPath: attachment.filename).pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let destination: URL
            if let resourceDirectory {
                destination = resourceDirectory.appendingPathComponent(UUID().uuidString)
            } else {
                destination = try ResourceFileStore.resourceFileURL(filename: attachment.filename, mimeType: mimeType,
                    accountKey: accountKey, resourceId: "restore-\(UUID().uuidString)")
            }
            createdFiles.append(destination)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: data.files[attachment.file]!, to: destination)
            let createdAt = try LocalBackupArchive.date(attachment.createdAt)
            let resource = StoredResource(accountKey: accountKey, filename: attachment.filename, size: Int(attachment.size),
                mimeType: mimeType, createdAt: createdAt, updatedAt: createdAt, urlString: destination.absoluteString,
                localPath: destination.path, memo: attachment.memoId.flatMap { inserted[$0] })
            resource.backupId = attachment.id
            context.insert(resource)
            importedAttachments += 1
        }
        try context.save()
        committed = true
        let identifiers = Set(inserted.values.map { MemoEntityIdentifier(accountKey: accountKey, persistentID: $0.id) })
        await MemoChanges.shared.didSave(identifiers: identifiers, container: container)
        return LocalImportResult(importedMemos: pending.count, skippedMemos: data.manifest.memos.count - pending.count,
            importedAttachments: importedAttachments, skippedAttachments: data.manifest.attachments.count - importedAttachments)
    }

    private func memos(in context: ModelContext) throws -> [StoredMemo] {
        let key = accountKey
        return try context.fetch(FetchDescriptor<StoredMemo>(predicate: #Predicate { $0.accountKey == key }))
    }

    private func resources(in context: ModelContext) throws -> [StoredResource] {
        let key = accountKey
        return try context.fetch(FetchDescriptor<StoredResource>(predicate: #Predicate { $0.accountKey == key }))
    }

    private static func visibility(_ visibility: MemoVisibility) -> String {
        switch visibility {
        case .public, .unlisted: "PUBLIC"
        case .local: "PROTECTED"
        case .space: "SPACE"
        case .private, .direct: "PRIVATE"
        }
    }

    private static func visibility(_ visibility: String) -> MemoVisibility {
        switch visibility {
        case "PUBLIC": .public
        case "PROTECTED": .local
        case "SPACE": .space
        default: .private
        }
    }
}
