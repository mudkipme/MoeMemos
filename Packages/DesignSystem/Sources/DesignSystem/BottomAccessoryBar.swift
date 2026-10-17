import SwiftUI

public extension View {
    /// Reserves room for interactive bottom content, including keyboard and scroll-edge effects.
    func bottomAccessoryBar<Bar: View>(@ViewBuilder content: () -> Bar) -> some View {
        modifier(BottomAccessoryBar(bar: content()))
    }
}

private struct BottomAccessoryBar<Bar: View>: ViewModifier {
    let bar: Bar

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            content.safeAreaBar(edge: .bottom) { bar }
        } else {
            content.safeAreaInset(edge: .bottom) { bar }
        }
    }
}
