import Foundation
import Observation

/// Imports into local storage one at a time, retaining only unsuccessful inputs for retry.
@MainActor
@Observable
final class MemoAttachmentImporter {
    struct Input: Identifiable {
        let id = UUID()
        let name: String
        let operation: @MainActor () async throws -> Void
    }

    enum State {
        case pending
        case importing
        case failed(String)
    }

    struct Item: Identifiable {
        let input: Input
        var state: State = .pending
        var id: UUID { input.id }
    }

    private(set) var items: [Item] = []
    private(set) var isImporting = false
    var hasUnfinishedImports: Bool { !items.isEmpty }

    func importItems(_ inputs: [Input]) async {
        items.append(contentsOf: inputs.map { Item(input: $0) })
        await drain()
    }

    func retry(id: UUID) async {
        guard let index = items.firstIndex(where: { $0.id == id }),
              case .failed = items[index].state else { return }
        items[index].state = .pending
        await drain()
    }

    func remove(id: UUID) {
        items.removeAll { item in
            guard item.id == id else { return false }
            if case .importing = item.state { return false }
            return true
        }
    }

    private func drain() async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        while let index = items.firstIndex(where: { if case .pending = $0.state { return true }; return false }) {
            let input = items[index].input
            items[index].state = .importing
            do {
                try Task.checkCancellation()
                try await input.operation()
                items.removeAll { $0.id == input.id }
            } catch {
                if let index = items.firstIndex(where: { $0.id == input.id }) {
                    items[index].state = .failed(error.localizedDescription)
                }
            }
        }
    }
}

enum MemoEditorError: LocalizedError {
    case accountChanged
    case unreadableAttachment

    var errorDescription: String? {
        switch self {
        case .accountChanged: NSLocalizedString("input.account-changed", comment: "Editor account changed")
        case .unreadableAttachment: NSLocalizedString("input.import-unreadable", comment: "Attachment could not be read")
        }
    }
}
