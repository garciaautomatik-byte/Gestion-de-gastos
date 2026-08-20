import SwiftUI

/// The app's dark theme is a tinted, near-black green (à la the reference app) rather than
/// neutral pure black — applied globally via `UITableView.appearance()` in `FinanceAppApp`, plus
/// these tokens for custom card surfaces that don't come from a `List`'s own background.
extension Color {
    static let appBackground = Color(hex: "#0F2419")
    static let appCard = Color(hex: "#17301F")
    static let appCardSecondary = Color(hex: "#1F3D28")
}

extension View {
    /// Every top-level `List`/`Form` paints its own opaque system background by default, which
    /// hides whatever color sits behind it (and reads as flat black in dark mode). Call this on
    /// every top-level List/Form in the app so the dark green theme actually shows through.
    func themedListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
    }
}

/// Shared tactile press feedback (per Apple/emil-kowalski design guidance: buttons must feel
/// instantly responsive — respond on press, not just on release) for plain-style buttons.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
