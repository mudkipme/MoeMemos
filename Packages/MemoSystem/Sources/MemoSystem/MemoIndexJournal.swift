import Foundation
import MemoData

/// Each process writes separate, atomic records, so an extension cannot overwrite
/// changes queued by the app. Records are removed only after Spotlight succeeds.
@MainActor
final class MemoIndexJournal {
    struct Entry: Codable {
        let id: UUID
        // nil requests a full repair, including removal of stale index entries.
        let identifiers: Set<String>?
    }

    private let directory: URL
    private var readyURL: URL { directory.appendingPathComponent("initialized") }

    init(directory: URL) {
        self.directory = directory
    }

    static func live() -> MemoIndexJournal? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppInfo.groupContainerIdentifier)
            .map { MemoIndexJournal(directory: $0.appendingPathComponent("MemoSpotlightJournal-v1", isDirectory: true)) }
    }

    var isInitialized: Bool { FileManager.default.fileExists(atPath: readyURL.path) }

    func append(identifiers: Set<String>?) throws -> Entry {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let entry = Entry(id: UUID(), identifiers: identifiers)
        try JSONEncoder().encode(entry).write(to: url(for: entry), options: .atomic)
        return entry
    }

    func pending() throws -> [Entry] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { return nil }
                // A malformed record requires a repair; unreadable files must be
                // retried when protected data becomes available.
                let data: Data
                do { data = try Data(contentsOf: url) }
                catch CocoaError.fileReadNoSuchFile { return nil }
                return (try? JSONDecoder().decode(Entry.self, from: data)) ?? Entry(id: id, identifiers: nil)
            }
    }

    func complete(_ entries: [Entry]) throws {
        for entry in entries {
            let url = url(for: entry)
            do { try FileManager.default.removeItem(at: url) }
            catch CocoaError.fileNoSuchFile { continue }
        }
    }

    func markInitialized() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: readyURL, options: .atomic)
    }

    func invalidate() {
        try? FileManager.default.removeItem(at: readyURL)
    }

    private func url(for entry: Entry) -> URL {
        directory.appendingPathComponent(entry.id.uuidString).appendingPathExtension("json")
    }
}
