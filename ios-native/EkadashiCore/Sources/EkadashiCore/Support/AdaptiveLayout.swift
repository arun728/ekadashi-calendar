import Foundation

/// One pane (phones, the iPhone Duo's outer screen) or two side by side
/// (the Duo's inner screen, foldables and tablets).
public enum PaneLayout: Int, Sendable, Equatable {
    case single = 1
    case double = 2

    public var columns: Int { rawValue }
    public var isSideBySide: Bool { self == .double }
}

/// The width rule both apps follow on wide screens (docs/FOLDABLES.md;
/// test/fixtures/adaptive_layout.json, lib/widgets/adaptive_layout.dart).
/// Widths are the points a screen's content is given, after the side safe
/// areas: never the device, its orientation or the main screen's size.
public enum AdaptiveLayout {
    /// Content this wide or wider shows two panes. Every iPhone in portrait
    /// and the Duo's outer screen are narrower; its inner screen is wider,
    /// even beside the status bar.
    public static let twoPaneMinWidth = 560.0
    /// Single-column content (Settings, details) stops growing here.
    public static let readableMaxWidth = 720.0
    public static let paneSpacing = 16.0

    public static func panes(forWidth width: Double) -> PaneLayout {
        width >= twoPaneMinWidth ? .double : .single
    }

    /// The width readable content takes; 0 until the width is known.
    public static func readableWidth(forWidth width: Double) -> Double {
        guard width > 0 else { return 0 }
        return min(width, readableMaxWidth)
    }

    /// The margin on each side that centres the readable width.
    public static func sideMargin(forWidth width: Double) -> Double {
        guard width.isFinite, width > 0 else { return 0 }
        return (width - readableWidth(forWidth: width)) / 2
    }
}
