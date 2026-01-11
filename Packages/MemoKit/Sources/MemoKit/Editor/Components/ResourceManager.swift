import Foundation

public protocol ResourceManager {
    @MainActor
    func deleteResource(remoteId: String) async throws
}
