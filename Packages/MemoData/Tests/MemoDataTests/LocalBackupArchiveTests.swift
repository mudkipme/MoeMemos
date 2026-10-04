import CryptoKit
import Foundation
import XCTest
import ZIPFoundation
@testable import MemoData

final class LocalBackupArchiveTests: XCTestCase {
    private var directory: URL!
    private let date = "2026-10-05T01:02:03.123456789Z"

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    private func sample() throws -> LocalBackupData {
        let source = directory.appendingPathComponent(UUID().uuidString)
        try Data([0, 1, 2, 255, 42]).write(to: source)
        let memo = LocalBackupMemo(id: "stable-memo-id", contentFile: "memos/0.md", createdAt: date,
            updatedAt: "2026-10-05T02:00:00Z", visibility: "PROTECTED", pinned: true, archived: true)
        let attachment = LocalBackupAttachment(id: "stable-attachment-id", memoId: memo.id,
            filename: "写真 09:30.png", mimeType: "image/png", createdAt: date, file: "attachments/0")
        return LocalBackupData(manifest: LocalBackupManifest(exportedAt: date, memos: [memo], attachments: [attachment]),
            contents: [memo.contentFile: "# 旅行\r\n\r\n- [x] task\n```\n#literal\n```\n"], files: [attachment.file: source])
    }

    private func write(_ data: LocalBackupData) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).zip")
        try LocalBackupArchive.write(data, to: url)
        return url
    }

    private func read(_ url: URL) throws -> LocalBackupData {
        try LocalBackupArchive.read(url, stagingDirectory: directory.appendingPathComponent(UUID().uuidString),
                                    legacyZone: TimeZone(identifier: "Asia/Singapore")!)
    }

    private func zip(_ entries: [(String, Data)]) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).zip")
        let archive = try Archive(url: url, accessMode: .create)
        for (path, bytes) in entries {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(bytes.count), compressionMethod: .deflate) { offset, count in
                bytes.subdata(in: Int(offset)..<(Int(offset) + count))
            }
        }
        return url
    }

    func testExportNeverDeletesAnExistingDestination() throws {
        let url = directory.appendingPathComponent("existing.zip")
        let original = Data("keep this file".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try LocalBackupArchive.write(sample(), to: url))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testAndroidDefaultFieldsAndJavaLegacyIdentity() throws {
        let json = Data(#"{"id":"empty","memoId":null,"filename":"empty.txt","mimeType":null,"createdAt":"2026-10-05T01:02:03Z","file":"attachments/0","sha256":"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"}"#.utf8)
        let attachment = try JSONDecoder().decode(LocalBackupAttachment.self, from: json)
        XCTAssertEqual(attachment.size, 0)
        // java.util.UUID.nameUUIDFromBytes("moe-memos-legacy:example".toByteArray())
        XCTAssertEqual(LocalBackupArchive.legacyIdentifier("example"), "d41ece60-cd31-3bba-89d2-ed2d2ee55280")
    }

    func testRoundTripPreservesMetadataUnicodeMarkdownAndBytes() throws {
        let data = try sample()
        let restored = try read(write(data))
        XCTAssertEqual(restored.manifest.memos, data.manifest.memos)
        XCTAssertEqual(restored.contents, data.contents)
        let attachment = try XCTUnwrap(restored.manifest.attachments.first)
        XCTAssertEqual(attachment.size, 5)
        XCTAssertEqual(attachment.filename, "写真 09:30.png")
        XCTAssertEqual(attachment.sha256, LocalBackupArchive.hex(SHA256.hash(data: Data([0, 1, 2, 255, 42]))))
        XCTAssertEqual(try Data(contentsOf: restored.files[attachment.file]!), Data([0, 1, 2, 255, 42]))
        XCTAssertFalse(restored.legacy)
        XCTAssertNoThrow(try LocalBackupArchive.date(date))
    }

    func testEmptyAndUnattachedResourcesAndExplicitNulls() throws {
        var data = try sample()
        data.manifest.memos = []
        data.contents = [:]
        data.manifest.attachments[0].memoId = nil
        data.manifest.attachments[0].mimeType = nil
        let restored = try read(write(data))
        XCTAssertNil(restored.manifest.attachments[0].memoId)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored.manifest.attachments[0])) as? [String: Any])
        XCTAssertTrue(json["memoId"] is NSNull)
        XCTAssertTrue(json["mimeType"] is NSNull)
        data.manifest.attachments = []
        XCTAssertTrue(try read(write(data)).manifest.memos.isEmpty)
    }

    func testLegacyAndroidAndIOSRecoverDatesCollisionsAndAttachmentAssociations() throws {
        for prefix in ["", "2026/10/"] {
            let entries: [(String, Data)] = [
                (prefix + "20261005-090203.md", Data("first #旅行".utf8)),
                (prefix + "20261005-090203_1.md", Data("second".utf8)),
                (prefix + "20261005-090203-1.png", Data([1])),
                (prefix + "20261005-090203-2", Data([2])),
                (prefix + "20261005-090203_1-1.md", Data("Markdown attachment".utf8)),
                ("unrelated.txt", Data([3]))]
            let restored = try read(zip(entries))
            XCTAssertTrue(restored.legacy)
            XCTAssertEqual(restored.manifest.memos.count, 2)
            XCTAssertEqual(restored.manifest.attachments.count, 3)
            XCTAssertEqual(restored.ignoredFiles, 1)
            XCTAssertEqual(try LocalBackupArchive.date(restored.manifest.memos[0].createdAt), try LocalBackupArchive.date("2026-10-05T01:02:03Z"))
            XCTAssertEqual(restored.manifest.attachments.filter { $0.memoId == restored.manifest.memos[0].id }.count, 2)
            let again = try read(zip(entries.reversed()))
            XCTAssertEqual(restored.manifest.memos, again.manifest.memos)
            XCTAssertEqual(restored.manifest.attachments, again.manifest.attachments)
            XCTAssertEqual(try read(write(restored)).manifest, restored.manifest)
        }
    }

    func testInvalidLegacyDateFallsBackAndUnrelatedZipIsRejected() throws {
        XCTAssertEqual(try read(zip([("20260230-090203.md", Data("recover".utf8))])).contents.values.first, "recover")
        XCTAssertThrowsError(try read(zip([("notes.md", Data("unrelated".utf8))])))
    }

    func testRejectsBadManifestMissingFilesAndCorruptionWithoutLegacyFallback() throws {
        let original = try read(write(sample()))
        var invalid = original.manifest
        invalid.version = 2
        XCTAssertThrowsError(try read(zip([("manifest.json", JSONEncoder().encode(invalid)), ("20261005-090203.md", Data())])))
        invalid = original.manifest
        invalid.format = "other"
        XCTAssertThrowsError(try LocalBackupArchive.validate(invalid))
        invalid = original.manifest
        invalid.memos.append(invalid.memos[0])
        XCTAssertThrowsError(try LocalBackupArchive.validate(invalid))
        invalid = original.manifest
        invalid.attachments[0].memoId = "missing"
        XCTAssertThrowsError(try LocalBackupArchive.validate(invalid))
        let manifest = try JSONEncoder().encode(original.manifest)
        let content = Data(original.contents["memos/0.md"]!.utf8)
        for entries in [
            [("manifest.json", manifest), ("memos/0.md", content)],
            [("manifest.json", manifest), ("attachments/0", Data([0, 1, 2, 255, 42]))],
            [("manifest.json", manifest), ("memos/0.md", content), ("attachments/0", Data([5, 4, 3, 2, 1]))]
        ] { XCTAssertThrowsError(try read(zip(entries))) }
    }

    func testRejectsUnsafePathsDuplicatesOversizedTextAndBadFilenames() throws {
        for path in ["../outside", "/absolute", "a/../../outside", "a\\outside", "C:outside"] {
            XCTAssertThrowsError(try read(zip([("20261005-090203.md", Data()), (path, Data())])))
        }
        XCTAssertThrowsError(try read(zip([("20261005-090203.md", Data()), ("20261005-090203.md", Data())])))
        XCTAssertThrowsError(try read(zip([("20261005-090203.md", Data(repeating: 65, count: Int(LocalBackupArchive.maxMemoBytes) + 1))])))
        let data = try read(write(sample()))
        for filename in ["../bad", "a/b", "a\\b", ".", "..", ""] {
            var manifest = data.manifest
            manifest.attachments[0].filename = filename
            XCTAssertThrowsError(try LocalBackupArchive.validate(manifest))
        }
    }
}
