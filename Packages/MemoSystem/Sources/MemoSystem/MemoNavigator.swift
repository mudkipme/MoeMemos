/// The app supplies navigation; the system integration has no dependency on
/// its routes, sheets, account screens, or SwiftUI environment.
@MainActor
public final class MemoNavigator: Sendable {
    private let open: @MainActor (String) throws -> Void

    public init(open: @escaping @MainActor (String) throws -> Void) {
        self.open = open
    }

    public func openMemo(identifier: String) throws {
        try open(identifier)
    }
}
