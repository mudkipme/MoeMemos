import SwiftUI

public extension ToolbarContent {
    /// Prefer essential actions over overflow when a resizable toolbar runs out of space.
    func prioritizeVisibility() -> some ToolbarContent {
        PrioritizedToolbarContent(content: self)
    }
}

// Keep availability-generated opaque types inside DesignSystem for Release linking.
private struct PrioritizedToolbarContent<Content: ToolbarContent>: ToolbarContent {
    let content: Content

    var body: some ToolbarContent {
#if os(iOS)
        if #available(iOS 27, *) {
            content.visibilityPriority(.high)
        } else {
            content
        }
#else
        content
#endif
    }
}
