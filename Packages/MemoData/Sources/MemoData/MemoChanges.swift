import Models
import SwiftData

/// Optional downstream work after a successful data commit. The data layer
/// neither knows about Spotlight nor requires an observer to operate.
@MainActor
public protocol MemoChangeObserver: AnyObject {
    func memosDidSave(identifiers: Set<MemoEntityIdentifier>, container: ModelContainer)
    func flush() async
}

@MainActor
public final class MemoChanges {
    public static let shared = MemoChanges()
    public weak var observer: (any MemoChangeObserver)?

    public init() {}

    public func didSave(identifiers: Set<MemoEntityIdentifier>, container: ModelContainer) {
        guard !identifiers.isEmpty else { return }
        observer?.memosDidSave(identifiers: identifiers, container: container)
    }

    public func flush() async {
        await observer?.flush()
    }
}
