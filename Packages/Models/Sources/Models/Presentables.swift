import Foundation
import SwiftData

/// Lightweight protocols used by rendering code so it can work with both:
/// - Remote DTOs (`Memo` / `Resource`)
/// - Local SwiftData models (`StoredMemo` / `StoredResource`)
public protocol ResourcePresentable {
    var filename: String { get }
    var size: Int { get }
    var mimeType: String { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var urlString: String { get }
}

public protocol MemoPresentable {
    var user: RemoteUser? { get }
    var content: String { get }
    var pinned: Bool { get }
    var rowStatus: RowStatus { get }
    var visibility: MemoVisibility { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var attachments: [any ResourcePresentable] { get }
}

public extension ResourcePresentable {
    var url: URL? { URL(string: urlString) }
}

public extension MemoPresentable {
    func renderTime(now: Date = .now) -> String {
        if (Calendar.current.dateComponents([.day], from: createdAt, to: now).day ?? 0) > 7 {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: createdAt, relativeTo: now)
    }
}

// MARK: - Conformances (Remote DTOs)

extension Resource: ResourcePresentable {
    public var urlString: String { url.absoluteString }
}

extension Memo: MemoPresentable {
    public var attachments: [any ResourcePresentable] { resources }
}

// MARK: - Conformances (SwiftData Models)

extension StoredMemo: MemoPresentable {
    public var user: RemoteUser? { nil }
    public var remoteId: String? { serverId }
    public var attachments: [any ResourcePresentable] {
        resources
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

extension StoredResource: ResourcePresentable {
    public var remoteId: String? { serverId }
}

extension StoredMemo: Identifiable {
    public var id: PersistentIdentifier { persistentModelID }
}

extension StoredResource: Identifiable {
    public var id: PersistentIdentifier { persistentModelID }
}
