import Foundation
import Network

/// Observes network path satisfaction changes so the app can trigger sync
/// automatically when connectivity returns after being offline.
public final class NetworkMonitor: Sendable {
    private let streamFactory: @Sendable () -> AsyncStream<Bool>

    public init() {
        self.streamFactory = {
            AsyncStream { continuation in
                let monitor = NWPathMonitor()
                let queue = DispatchQueue(label: "me.mudkip.MoeMemos.NetworkMonitor")
                monitor.pathUpdateHandler = { path in
                    continuation.yield(path.status == .satisfied)
                }
                continuation.onTermination = { _ in
                    monitor.cancel()
                }
                monitor.start(queue: queue)
            }
        }
    }

    /// Test initializer accepting a custom stream of online/offline transitions.
    public init(streamFactory: @escaping @Sendable () -> AsyncStream<Bool>) {
        self.streamFactory = streamFactory
    }

    public func connectivityUpdates() -> AsyncStream<Bool> {
        streamFactory()
    }
}
