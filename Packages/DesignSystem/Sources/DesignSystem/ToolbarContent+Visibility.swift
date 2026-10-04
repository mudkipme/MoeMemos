import SwiftUI

public extension ToolbarContent {
    /// Prefer essential actions over overflow when a resizable toolbar runs out of space.
    @ToolbarContentBuilder
    func prioritizeVisibility() -> some ToolbarContent {
#if os(iOS)
        if #available(iOS 27, *) {
            visibilityPriority(.high)
        } else {
            self
        }
#else
        self
#endif
    }
}
