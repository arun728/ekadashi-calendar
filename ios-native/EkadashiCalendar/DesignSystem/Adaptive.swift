import SwiftUI
import EkadashiCore

/// Wide screens (the iPhone Duo's inner screen) show two panes side by side
/// (docs/FOLDABLES.md). RootView measures each tab's width and passes it
/// down; screens decide with AdaptiveLayout, never from the device, its
/// orientation or the main screen. Unfolding resizes the app: the panes
/// switch in place (AnyLayout), so each screen keeps its state.
private struct LayoutWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// The width of the tab's content, after the side safe areas.
    var layoutWidth: CGFloat {
        get { self[LayoutWidthKey.self] }
        set { self[LayoutWidthKey.self] = newValue }
    }

    var paneLayout: PaneLayout { AdaptiveLayout.panes(forWidth: Double(layoutWidth)) }
}

extension View {
    /// Measures this view's width (again on every resize) for the views inside.
    func measuresPaneLayout() -> some View { modifier(PaneLayoutReader()) }

    /// Single-column content stops at the readable width, centred.
    func readableWidth(alignment: Alignment = .top) -> some View {
        frame(maxWidth: CGFloat(AdaptiveLayout.readableMaxWidth), alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    /// A List or Form centred at the readable width on wide screens; phones
    /// keep the system margins.
    func readableListMargins() -> some View { modifier(ReadableListMargins()) }
}

private struct PaneLayoutReader: ViewModifier {
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .environment(\.layoutWidth, width)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

private struct ReadableListMargins: ViewModifier {
    @Environment(\.layoutWidth) private var width

    func body(content: Content) -> some View {
        let margin = CGFloat(AdaptiveLayout.sideMargin(forWidth: Double(width)))
        content.contentMargins(.horizontal, margin > 0 ? margin : nil, for: .scrollContent)
    }
}

/// Two panes: side by side on wide screens (top aligned, equal widths),
/// stacked on phones in the same order.
struct AdaptivePanes<Leading: View, Trailing: View>: View {
    @Environment(\.paneLayout) private var panes
    var spacing = CGFloat(AdaptiveLayout.paneSpacing)
    /// The stacked spacing; phones keep each screen's own.
    var stackedSpacing: CGFloat = 12
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let layout = panes.isSideBySide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: spacing))
            : AnyLayout(VStackLayout(spacing: stackedSpacing))
        layout {
            leading.frame(maxWidth: .infinity, alignment: .top)
            trailing.frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
