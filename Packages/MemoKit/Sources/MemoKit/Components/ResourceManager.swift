import Foundation
import SwiftData

public protocol ResourceManager {
    @MainActor
    func deleteResource(id: PersistentIdentifier) async throws
}
