//
//  LocalMemoExporter.swift
//
//
//  Created by Codex on 2026/2/8.
//

import Foundation
import UniformTypeIdentifiers
import ZIPFoundation
import Models

struct LocalMemoExportProgress: Sendable {
    let completed: Int
    let total: Int
    let message: String

    var fractionCompleted: Double {
        guard total > 0 else { return 1.0 }
        return Double(completed) / Double(total)
    }
}

struct LocalMemoExportSnapshot: Sendable {
    let createdAt: Date
    let content: String
    let resources: [Resource]

    struct Resource: Sendable {
        let filename: String
        let mimeType: String
        let localPath: String?
        let urlString: String
    }
}

enum LocalMemoExportError: LocalizedError {
    case empty
    case missingResourceFile(filename: String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return NSLocalizedString("account.local-export-error-empty", comment: "No local memos to export")
        case let .missingResourceFile(filename):
            return String(
                format: NSLocalizedString(
                    "account.local-export-error-missing-resource",
                    comment: "Missing attachment file during local export"
                ),
                filename
            )
        }
    }
}

enum LocalMemoExporter {
    typealias ProgressHandler = @Sendable (LocalMemoExportProgress) async -> Void

    static func export(snapshots: [LocalMemoExportSnapshot], progress: @escaping ProgressHandler) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try await exportDetached(snapshots: snapshots, progress: progress)
        }.value
    }

    private static func exportDetached(snapshots: [LocalMemoExportSnapshot], progress: ProgressHandler) async throws -> URL {
        guard !snapshots.isEmpty else { throw LocalMemoExportError.empty }

        let fileManager = FileManager.default
        let workspaceURL = fileManager.temporaryDirectory
            .appendingPathComponent("MoeMemos-Export-\(UUID().uuidString)", isDirectory: true)
        let payloadURL = workspaceURL.appendingPathComponent("payload", isDirectory: true)
        try fileManager.createDirectory(at: payloadURL, withIntermediateDirectories: true)

        defer { try? fileManager.removeItem(at: workspaceURL) }

        let totalSteps = snapshots.reduce(0) { partialResult, memo in
            partialResult + 1 + memo.resources.count
        } + 1
        var completedSteps = 0
        await progress(
            .init(
                completed: completedSteps,
                total: totalSteps,
                message: NSLocalizedString("account.local-export-progress-preparing", comment: "Preparing local export")
            )
        )

        var secondCollisionMap: [String: Int] = [:]
        let orderedMemos = snapshots.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.content < $1.content
            }
            return $0.createdAt < $1.createdAt
        }

        for memo in orderedMemos {
            let memoBaseName = uniqueMemoBaseName(for: memo.createdAt, collisionMap: &secondCollisionMap)
            let destinationDirectory = payloadURL.appendingPathComponent(directoryPath(for: memo.createdAt), isDirectory: true)
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            let markdownURL = destinationDirectory.appendingPathComponent("\(memoBaseName).md", isDirectory: false)
            try memo.content.write(to: markdownURL, atomically: true, encoding: .utf8)
            completedSteps += 1
            await progress(
                .init(
                    completed: completedSteps,
                    total: totalSteps,
                    message: NSLocalizedString("account.local-export-progress-exporting", comment: "Exporting memos and resources")
                )
            )

            let orderedResources = memo.resources.sorted {
                if $0.filename == $1.filename {
                    return $0.urlString < $1.urlString
                }
                return $0.filename < $1.filename
            }

            for (index, resource) in orderedResources.enumerated() {
                guard let sourceURL = localFileURL(for: resource), fileManager.fileExists(atPath: sourceURL.path) else {
                    throw LocalMemoExportError.missingResourceFile(filename: resource.filename)
                }

                let ext = fileExtension(for: resource, sourceURL: sourceURL)
                let targetName = ext.isEmpty
                    ? "\(memoBaseName)-\(index + 1)"
                    : "\(memoBaseName)-\(index + 1).\(ext)"
                let destinationURL = destinationDirectory.appendingPathComponent(targetName, isDirectory: false)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                completedSteps += 1
                await progress(
                    .init(
                        completed: completedSteps,
                        total: totalSteps,
                        message: NSLocalizedString("account.local-export-progress-exporting", comment: "Exporting memos and resources")
                    )
                )
            }
        }

        await progress(
            .init(
                completed: completedSteps,
                total: totalSteps,
                message: NSLocalizedString("account.local-export-progress-zipping", comment: "Creating zip archive for local export")
            )
        )
        let zipURL = fileManager.temporaryDirectory
            .appendingPathComponent("MoeMemos-Export-\(archiveTimestamp(from: Date())).zip", isDirectory: false)
        if fileManager.fileExists(atPath: zipURL.path) {
            try? fileManager.removeItem(at: zipURL)
        }
        try createZip(from: payloadURL, to: zipURL, fileManager: fileManager)
        completedSteps += 1
        await progress(
            .init(
                completed: completedSteps,
                total: totalSteps,
                message: NSLocalizedString("account.local-export-progress-complete", comment: "Local export complete")
            )
        )
        return zipURL
    }

    private static func uniqueMemoBaseName(for date: Date, collisionMap: inout [String: Int]) -> String {
        let base = secondTimestamp(from: date)
        let count = collisionMap[base, default: 0]
        collisionMap[base] = count + 1
        return count == 0 ? base : "\(base)_\(count)"
    }

    private static func directoryPath(for date: Date) -> String {
        let components = dateComponents(from: date)
        return String(format: "%04d/%02d", components.year, components.month)
    }

    private static func secondTimestamp(from date: Date) -> String {
        let components = dateComponents(from: date)
        return String(
            format: "%04d%02d%02d-%02d%02d%02d",
            components.year,
            components.month,
            components.day,
            components.hour,
            components.minute,
            components.second
        )
    }

    private static func archiveTimestamp(from date: Date) -> String {
        secondTimestamp(from: date)
    }

    private static func localFileURL(for resource: LocalMemoExportSnapshot.Resource) -> URL? {
        if let localPath = resource.localPath, !localPath.isEmpty {
            return URL(fileURLWithPath: localPath)
        }
        guard let url = URL(string: resource.urlString), url.isFileURL else {
            return nil
        }
        return url
    }

    private static func fileExtension(for resource: LocalMemoExportSnapshot.Resource, sourceURL: URL) -> String {
        let fromFilename = URL(fileURLWithPath: resource.filename).pathExtension
        if !fromFilename.isEmpty {
            return fromFilename
        }
        let fromSource = sourceURL.pathExtension
        if !fromSource.isEmpty {
            return fromSource
        }
        if let type = UTType(mimeType: resource.mimeType), let preferred = type.preferredFilenameExtension {
            return preferred
        }
        return ""
    }

    private static func createZip(from rootDirectory: URL, to zipURL: URL, fileManager: FileManager) throws {
        let archive = try Archive(url: zipURL, accessMode: .create)
        let fileURLs = try allFiles(in: rootDirectory, fileManager: fileManager)
        for fileURL in fileURLs {
            let relativePath = fileURL.path.replacingOccurrences(of: "\(rootDirectory.path)/", with: "")
            try archive.addEntry(with: relativePath, relativeTo: rootDirectory)
        }
    }

    private static func allFiles(in rootDirectory: URL, fileManager: FileManager) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            if values.isDirectory == true {
                continue
            }
            if values.isRegularFile == true {
                files.append(url)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func dateComponents(from date: Date) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return (
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0
        )
    }
}
