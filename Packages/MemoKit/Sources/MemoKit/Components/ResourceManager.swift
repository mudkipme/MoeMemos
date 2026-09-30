import Foundation
import SwiftData

public protocol ResourceManager {
    @MainActor
    var removalLabel: String { get }

    @MainActor
    func deleteResource(id: PersistentIdentifier) async throws
}

public extension ResourceManager {
    @MainActor
    var removalLabel: String { NSLocalizedString("Delete", comment: "Delete attachment") }
}
