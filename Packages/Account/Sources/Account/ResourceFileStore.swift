//
//  ResourceFileStore.swift
//
//
//  Created by Mudkip on 2026/2/3.
//

import Foundation
import UniformTypeIdentifiers
import SwiftData
import Models

enum ResourceFileStore {
    static func store(data: Data, filename: String, mimeType: String, accountKey: String, resourceId: String) throws -> URL {
        let destination = try resourceFileURL(filename: filename, mimeType: mimeType, accountKey: accountKey, resourceId: resourceId)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    static func store(fileAt sourceURL: URL, filename: String, mimeType: String, accountKey: String, resourceId: String) throws -> URL {
        guard sourceURL.isFileURL else { throw MoeMemosError.invalidParams }
        let destination = try resourceFileURL(filename: filename, mimeType: mimeType, accountKey: accountKey, resourceId: resourceId)
        let fileManager = FileManager.default

        if sourceURL.standardizedFileURL == destination.standardizedFileURL {
            return destination
        }

        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destination)
        } catch {
            try fileManager.copyItem(at: sourceURL, to: destination)
            try? fileManager.removeItem(at: sourceURL)
        }
        return destination
    }

    static func deleteFile(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteFile(atPath path: String?) {
        guard let path else { return }
        deleteFile(at: URL(fileURLWithPath: path))
    }

    static func deleteAccountFiles(accountKey: String) {
        guard let directory = try? resourcesDirectory(accountKey: accountKey) else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor
    static func cleanupOrphanedFiles(context: ModelContext) throws {
        let fileManager = FileManager.default
        let descriptor = FetchDescriptor<StoredResource>()
        let resources = try context.fetch(descriptor)
        let keepPaths = Set(resources.filter { !$0.isDeleted }.compactMap(\.localPath))
        let deletePaths = Set(resources.filter { $0.isDeleted }.compactMap(\.localPath))

        for path in deletePaths {
            deleteFile(atPath: path)
        }

        let root = try resourcesRootDirectory()
        if !fileManager.fileExists(atPath: root.path) {
            return
        }

        if let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let fileURL as URL in enumerator {
                let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDirectory {
                    continue
                }
                if !keepPaths.contains(fileURL.path) {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }

    private static func resourcesRootDirectory() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppInfo.groupContainerIdentifier) else {
            throw MoeMemosError.unknown
        }
        return containerURL
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
    }

    private static func resourcesDirectory(accountKey: String) throws -> URL {
        let root = try resourcesRootDirectory()
        let safeAccount = accountKey.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        return root.appendingPathComponent(safeAccount, isDirectory: true)
    }

    private static func resourceFileURL(filename: String, mimeType: String, accountKey: String, resourceId: String) throws -> URL {
        let directory = try resourcesDirectory(accountKey: accountKey)
        let pathExtension = resolveExtension(filename: filename, mimeType: mimeType)
        let fileName = pathExtension.isEmpty ? resourceId : "\(resourceId).\(pathExtension)"
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func resolveExtension(filename: String, mimeType: String) -> String {
        let ext = URL(fileURLWithPath: filename).pathExtension
        if !ext.isEmpty {
            return ext
        }
        if let utType = UTType(mimeType: mimeType), let preferred = utType.preferredFilenameExtension {
            return preferred
        }
        return ""
    }
}
