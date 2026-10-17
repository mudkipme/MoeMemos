import SwiftUI

public extension View {
    /// Keeps search as a button until activated, leaving room for content and other actions.
    func compactSearchToolbar() -> some View {
        modifier(CompactSearchToolbar())
    }
}

private struct CompactSearchToolbar: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS) || os(visionOS)
        if #available(iOS 26, visionOS 26, *) {
            content.searchToolbarBehavior(.minimize)
        } else {
            content
        }
#else
        content
#endif
    }
}
