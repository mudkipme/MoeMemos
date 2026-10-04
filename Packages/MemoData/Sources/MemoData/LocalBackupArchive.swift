import CryptoKit
import Foundation
import ZIPFoundation

// Version 1 is shared with MoeMemosAndroid's LocalBackupArchive. Keep the wire
// names, visibility values, limits and legacy ID algorithm identical.
struct LocalBackupManifest: Codable, Sendable, Equatable {
    var format = "moe-memos-local"
    var version = 1
    var exportedAt: String
    var memos: [LocalBackupMemo]
    var attachments: [LocalBackupAttachment]
}

struct LocalBackupMemo: Codable, Sendable, Equatable {
    var id: String
    var contentFile: String
    var createdAt: String
    var updatedAt: String
    var visibility: String
    var pinned: Bool
    var archived: Bool
}

struct LocalBackupAttachment: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case id, memoId, filename, mimeType, createdAt, file, size, sha256
    }

    var id: String
    var memoId: String?
    var filename: String
    var mimeType: String?
    var createdAt: String
    var file: String
    var size: Int64 = 0
    var sha256: String = ""

    // Kotlin encodes nullable fields explicitly, including unattached resources.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(memoId, forKey: .memoId)
        try c.encode(filename, forKey: .filename)
        try c.encode(mimeType, forKey: .mimeType)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(file, forKey: .file)
        try c.encode(size, forKey: .size)
        try c.encode(sha256, forKey: .sha256)
    }
}

extension LocalBackupAttachment {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        memoId = try c.decodeIfPresent(String.self, forKey: .memoId)
        filename = try c.decode(String.self, forKey: .filename)
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        file = try c.decode(String.self, forKey: .file)
        size = try c.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        sha256 = try c.decodeIfPresent(String.self, forKey: .sha256) ?? ""
    }
}

struct LocalBackupData: Sendable {
    var manifest: LocalBackupManifest
    var contents: [String: String]
    var files: [String: URL]
    var legacy = false
    var ignoredFiles = 0
}

struct LocalBackupError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum LocalBackupArchive {
    static let maxArchiveBytes: Int64 = 4 * 1024 * 1024 * 1024
    static let maxExpandedBytes: Int64 = 8 * 1024 * 1024 * 1024
    static let maxManifestBytes: Int64 = 16 * 1024 * 1024
    static let maxMemoBytes: Int64 = 4 * 1024 * 1024
    static let maxTextBytes: Int64 = 64 * 1024 * 1024
    static let maxEntries = 100_000

    static func timestamp(_ date: Date) -> String {
        // Foundation's default formatter emits only milliseconds. Retain the
        // submillisecond precision available in Date when moving between clients.
        let seconds = floor(date.timeIntervalSince1970)
        let nanos = Int((date.timeIntervalSince1970 - seconds) * 1_000_000_000)
        let base = Date(timeIntervalSince1970: seconds).ISO8601Format()
        return String(base.dropLast()) + String(format: ".%09dZ", nanos)
    }

    static func date(_ value: String) throws -> Date {
        if let date = try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
        if let date = try? Date(value, strategy: .iso8601) { return date }
        throw LocalBackupError("Invalid backup date: \(value)")
    }

    static func write(_ data: LocalBackupData, to destination: URL,
                      progress: (Int, Int) -> Void = { _, _ in }) throws {
        var manifest = data.manifest
        for index in manifest.attachments.indices {
            try Task.checkCancellation()
            let attachment = manifest.attachments[index]
            guard let source = data.files[attachment.file] else { throw LocalBackupError("Missing attachment: \(attachment.filename)") }
            let (size, hash) = try digest(source)
            manifest.attachments[index].size = size
            manifest.attachments[index].sha256 = hash
        }
        try validate(manifest)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let metadata = try encoder.encode(manifest)
        try require(metadata.count <= maxManifestBytes, "Backup metadata is too large")
        let archive = try Archive(url: destination, accessMode: .create)
        var succeeded = false
        defer { if !succeeded { try? FileManager.default.removeItem(at: destination) } }
        let total = manifest.memos.count + manifest.attachments.count + 1
        var completed = 0
        var textBytes: Int64 = 0
        func add(_ bytes: Data, at path: String) throws {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(bytes.count), compressionMethod: .deflate) { offset, count in
                try Task.checkCancellation()
                return bytes.subdata(in: Int(offset)..<(Int(offset) + count))
            }
            completed += 1
            progress(completed, total)
        }
        try add(metadata, at: "manifest.json")
        for memo in manifest.memos {
            guard let content = data.contents[memo.contentFile] else { throw LocalBackupError("Missing memo: \(memo.contentFile)") }
            let bytes = Data(content.utf8)
            textBytes += Int64(bytes.count)
            try require(bytes.count <= maxMemoBytes && textBytes <= maxTextBytes, "Backup contains too much text")
            try add(bytes, at: memo.contentFile)
        }
        for attachment in manifest.attachments {
            let source = data.files[attachment.file]!
            let handle = try FileHandle(forReadingFrom: source)
            defer { try? handle.close() }
            var hash = SHA256()
            var copied: Int64 = 0
            try archive.addEntry(with: attachment.file, type: .file, uncompressedSize: attachment.size, compressionMethod: .deflate) { _, count in
                try Task.checkCancellation()
                let bytes = try handle.read(upToCount: count) ?? Data()
                try require(bytes.count == count, "Attachment changed while exporting: \(attachment.filename)")
                copied += Int64(bytes.count)
                hash.update(data: bytes)
                return bytes
            }
            try require(copied == attachment.size && hex(hash.finalize()) == attachment.sha256 &&
                        (try handle.read(upToCount: 1) ?? Data()).isEmpty,
                        "Attachment changed while exporting: \(attachment.filename)")
            completed += 1
            progress(completed, total)
        }
        try require(try fileSize(destination) <= maxArchiveBytes, "Backup is too large")
        succeeded = true
    }

    // Never extract to a path supplied by the ZIP or manifest. All attachment
    // destinations are generated, and every referenced entry is CRC/SHA checked.
    static func read(_ source: URL, stagingDirectory: URL, legacyZone: TimeZone = .current) throws -> LocalBackupData {
        try require(try fileSize(source) <= maxArchiveBytes, "Backup is too large")
        let archive = try Archive(url: source, accessMode: .read)
        var entries: [String: Entry] = [:]
        var names = Set<String>()
        for entry in archive {
            try Task.checkCancellation()
            try validatePath(entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path)
            try require(names.insert(entry.path).inserted && names.count <= maxEntries, "Duplicate entries or too many files in backup")
            try require(entry.type != .symlink, "Backup contains a symbolic link")
            if entry.type == .file { entries[entry.path] = entry }
        }
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        var expandedBytes: Int64 = 0
        var textBytes: Int64 = 0
        func extract(_ entry: Entry, limit: Int64, consume: (Data) throws -> Void) throws -> (Int64, String) {
            try require(entry.uncompressedSize <= UInt64(limit), "Backup entry exceeds the size limit")
            var size: Int64 = 0
            var hash = SHA256()
            let crc = try archive.extract(entry) { bytes in
                try Task.checkCancellation()
                size += Int64(bytes.count)
                expandedBytes += Int64(bytes.count)
                try require(size <= limit && expandedBytes <= maxExpandedBytes, "Backup is too large to restore")
                hash.update(data: bytes)
                try consume(bytes)
            }
            try require(UInt64(size) == entry.uncompressedSize && crc == entry.checksum, "Damaged backup entry: \(entry.path)")
            return (size, hex(hash.finalize()))
        }
        func text(_ entry: Entry, metadata: Bool = false) throws -> String {
            var bytes = Data()
            _ = try extract(entry, limit: metadata ? maxManifestBytes : maxMemoBytes) { bytes.append($0) }
            if !metadata { textBytes += Int64(bytes.count) }
            try require(textBytes <= maxTextBytes, "Backup contains too much text")
            guard let value = String(data: bytes, encoding: .utf8) else { throw LocalBackupError("Backup contains invalid UTF-8 text") }
            return value
        }
        func stage(_ entry: Entry) throws -> (URL, Int64, String) {
            let target = stagingDirectory.appendingPathComponent(UUID().uuidString)
            _ = FileManager.default.createFile(atPath: target.path, contents: nil)
            let handle = try FileHandle(forWritingTo: target)
            defer { try? handle.close() }
            let (size, hash) = try extract(entry, limit: maxExpandedBytes) { try handle.write(contentsOf: $0) }
            return (target, size, hash)
        }
        if let metadata = entries["manifest.json"] {
            let manifest = try JSONDecoder().decode(LocalBackupManifest.self, from: Data(text(metadata, metadata: true).utf8))
            try validate(manifest)
            var contents: [String: String] = [:]
            var files: [String: URL] = [:]
            for memo in manifest.memos {
                guard let entry = entries[memo.contentFile] else { throw LocalBackupError("Missing memo: \(memo.contentFile)") }
                contents[memo.contentFile] = try text(entry)
            }
            for attachment in manifest.attachments {
                guard let entry = entries[attachment.file] else { throw LocalBackupError("Missing attachment: \(attachment.filename)") }
                let (url, size, hash) = try stage(entry)
                try require(size == attachment.size && hash == attachment.sha256, "Damaged attachment: \(attachment.filename)")
                files[attachment.file] = url
            }
            return LocalBackupData(manifest: manifest, contents: contents, files: files,
                                   ignoredFiles: entries.count - 1 - contents.count - files.count)
        }
        var memos: [LocalBackupMemo] = []
        var byBase: [String: LocalBackupMemo] = [:]
        var contents: [String: String] = [:]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = legacyZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.isLenient = false
        for name in entries.keys.sorted() {
            // Android exported at the root; iOS exported under yyyy/MM/.
            guard name.range(of: #"^(?:[0-9]{4}/[0-9]{2}/)?[0-9]{8}-[0-9]{6}(?:_[0-9]+)?\.md$"#, options: .regularExpression) != nil else { continue }
            let entry = entries[name]!
            let content = try text(entry)
            let base = String(name.dropLast(3))
            let stamp = String(URL(fileURLWithPath: base).lastPathComponent.prefix(15))
            let parsed = formatter.date(from: stamp)
            let created = parsed.flatMap { formatter.string(from: $0) == stamp ? $0 : nil }
                ?? (entry.fileAttributes[.modificationDate] as? Date) ?? Date(timeIntervalSince1970: 0)
            let memo = LocalBackupMemo(id: legacyIdentifier("memo:\(name):\(hex(SHA256.hash(data: Data(content.utf8))))"),
                                      contentFile: name, createdAt: timestamp(created), updatedAt: timestamp(created),
                                      visibility: "PRIVATE", pinned: false, archived: false)
            memos.append(memo)
            byBase[base] = memo
            contents[name] = content
        }
        try require(!memos.isEmpty, "This ZIP is not a Moe Memos local backup")
        var attachments: [LocalBackupAttachment] = []
        var files: [String: URL] = [:]
        let pattern = try NSRegularExpression(pattern: #"^((?:[0-9]{4}/[0-9]{2}/)?[0-9]{8}-[0-9]{6}(?:_[0-9]+)?)-[0-9]+(?:\.[^/]*)?$"#)
        for name in entries.keys.sorted() {
            guard let match = pattern.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
                  let range = Range(match.range(at: 1), in: name), let memo = byBase[String(name[range])] else { continue }
            let (url, size, hash) = try stage(entries[name]!)
            files[name] = url
            attachments.append(LocalBackupAttachment(id: legacyIdentifier("attachment:\(memo.id):\(name):\(hash)"),
                memoId: memo.id, filename: URL(fileURLWithPath: name).lastPathComponent, mimeType: nil,
                createdAt: memo.createdAt, file: name, size: size, sha256: hash))
        }
        return LocalBackupData(manifest: LocalBackupManifest(exportedAt: timestamp(.now), memos: memos, attachments: attachments),
                               contents: contents, files: files, legacy: true, ignoredFiles: entries.count - contents.count - files.count)
    }

    static func validate(_ manifest: LocalBackupManifest) throws {
        try require(manifest.format == "moe-memos-local", "This is not a Moe Memos local backup")
        try require(manifest.version == 1, "Unsupported local backup version: \(manifest.version)")
        _ = try date(manifest.exportedAt)
        try require(manifest.memos.count + manifest.attachments.count + 1 <= maxEntries, "Too many files in backup")
        var memoIds = Set<String>()
        var attachmentIds = Set<String>()
        var paths: Set<String> = ["manifest.json"]
        for memo in manifest.memos {
            try validateId(memo.id)
            try require(memoIds.insert(memo.id).inserted, "Duplicate memo identifier")
            try validatePath(memo.contentFile)
            try require(paths.insert(memo.contentFile).inserted, "Duplicate content path")
            _ = try date(memo.createdAt)
            _ = try date(memo.updatedAt)
            try require(["PRIVATE", "PROTECTED", "PUBLIC", "SPACE"].contains(memo.visibility), "Unknown memo visibility")
        }
        var attachmentBytes: Int64 = 0
        for attachment in manifest.attachments {
            try validateId(attachment.id)
            try require(attachmentIds.insert(attachment.id).inserted, "Duplicate attachment identifier")
            try require(attachment.memoId == nil || memoIds.contains(attachment.memoId!), "Attachment refers to a missing memo")
            try validatePath(attachment.file)
            try require(paths.insert(attachment.file).inserted, "Duplicate attachment path")
            try require(!attachment.filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        ![".", ".."].contains(attachment.filename) &&
                        !attachment.filename.contains(where: { $0 == "/" || $0 == "\\" || $0 == "\0" }), "Invalid attachment filename")
            _ = try date(attachment.createdAt)
            try require((0...maxExpandedBytes).contains(attachment.size), "Invalid attachment size")
            attachmentBytes += attachment.size
            try require(attachmentBytes <= maxExpandedBytes - maxTextBytes - maxManifestBytes, "Backup attachments are too large")
            try require(attachment.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil, "Invalid attachment checksum")
        }
    }

    private static func validateId(_ id: String) throws {
        try require(!id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && id.utf16.count <= 256 &&
                    !id.unicodeScalars.contains(where: isControl), "Invalid backup identifier")
    }

    private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value < 32 || (127...159).contains(scalar.value)
    }

    private static func validatePath(_ path: String) throws {
        try require(!path.isEmpty && !path.contains("\\") && !path.contains(":") &&
                    !path.unicodeScalars.contains(where: isControl) &&
                    !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
                    "Unsafe backup path: \(path)")
    }

    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw LocalBackupError(message) }
    }

    static func fileSize(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        try require(url.isFileURL && values.isRegularFile == true, "Missing local attachment: \(url.lastPathComponent)")
        return Int64(values.fileSize ?? 0)
    }

    private static func digest(_ url: URL) throws -> (Int64, String) {
        _ = try fileSize(url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        var size: Int64 = 0
        while let bytes = try handle.read(upToCount: 64 * 1024), !bytes.isEmpty {
            try Task.checkCancellation()
            size += Int64(bytes.count)
            try require(size <= maxExpandedBytes, "Attachment is too large")
            hash.update(data: bytes)
        }
        return (size, hex(hash.finalize()))
    }

    static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    static func legacyIdentifier(_ value: String) -> String {
        // java.util.UUID.nameUUIDFromBytes: MD5 with RFC 4122 version/variant bits.
        var bytes = Array(Insecure.MD5.hash(data: Data("moe-memos-legacy:\(value)".utf8)))
        bytes[6] = (bytes[6] & 0x0f) | 0x30
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        let s = hex(bytes)
        return [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { range in
            String(s[s.index(s.startIndex, offsetBy: range.lowerBound)..<s.index(s.startIndex, offsetBy: range.upperBound)])
        }.joined(separator: "-")
    }
}
