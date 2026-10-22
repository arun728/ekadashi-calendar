import SwiftUI

/// Off means the existing system-managed appearance, not a new flat theme.
private struct GlassLookKey: EnvironmentKey { static let defaultValue = false }
enum GlassLookPolicy {
    static func isActive(preference: Bool, reduceTransparency: Bool) -> Bool {
        preference && !reduceTransparency
    }
}
extension EnvironmentValues {
    var glassLookEnabled: Bool {
        get { self[GlassLookKey.self] }
        set { self[GlassLookKey.self] = newValue }
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassPanelAppearance(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
    func glassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        modifier(GlassCapsuleAppearance(tint: tint, interactive: interactive))
    }
    func primaryActionStyle() -> some View { modifier(GlassActionAppearance(prominent: true)) }
    func secondaryActionStyle() -> some View { modifier(GlassActionAppearance(prominent: false)) }
    func glassSheetBackground() -> some View { modifier(GlassSheetAppearance()) }
    func glassListRows() -> some View { modifier(GlassListAppearance()) }
    func glassToolbarButton() -> some View { modifier(GlassToolbarAppearance()) }
}

/// Liquid Glass on iOS 26 (Apple's `glassEffect`), system materials before.
/// Built with Xcode 26; older compilers use the material fallback only.
extension View {
    /// A translucent glass panel (cards, sections).
    @ViewBuilder
    func legacyGlassPanel(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(Self.glass(tint: tint, interactive: interactive), in: .rect(cornerRadius: cornerRadius))
        } else {
            materialPanel(cornerRadius: cornerRadius, tint: tint)
        }
        #else
        materialPanel(cornerRadius: cornerRadius, tint: tint)
        #endif
    }

    /// A glass capsule (the Android "glass tube" option groups).
    @ViewBuilder
    func legacyGlassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(Self.glass(tint: tint, interactive: interactive), in: .capsule)
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7))
                .background((tint ?? .clear).opacity(0.25), in: Capsule())
        }
        #else
        self.background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.7))
            .background((tint ?? .clear).opacity(0.25), in: Capsule())
        #endif
    }

    private func materialPanel(cornerRadius: CGFloat, tint: Color?) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background((tint ?? .clear).opacity(0.16), in: shape)
            .background(.regularMaterial, in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.7))
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func glass(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint.opacity(0.35)) }
        if interactive { glass = glass.interactive() }
        return glass
    }
    #endif

    /// Primary call to action: prominent glass on iOS 26, a filled button before.
    @ViewBuilder
    func legacyPrimaryActionStyle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent).tint(Theme.teal)
        } else {
            self.buttonStyle(.borderedProminent).tint(Theme.teal)
        }
        #else
        self.buttonStyle(.borderedProminent).tint(Theme.teal)
        #endif
    }

    /// Secondary action: clear glass on iOS 26, a bordered button before.
    @ViewBuilder
    func legacySecondaryActionStyle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass).tint(Theme.teal)
        } else {
            self.buttonStyle(.bordered).tint(Theme.teal)
        }
        #else
        self.buttonStyle(.bordered).tint(Theme.teal)
        #endif
    }
}

/// Groups glass shapes so they blend and morph together on iOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content
    @Environment(\.glassLookEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if GlassLookPolicy.isActive(preference: enabled, reduceTransparency: reduceTransparency) {
            content()
        } else {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
        #else
        content()
        #endif
        }
    }
}

/// A selectable filter chip (Android GlassFilterChip).
struct GlassChip: View {
    let title: String
    var systemImage: String?
    var color: Color = Theme.teal
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).imageScale(.small) }
                Text(title).font(.subheadline.weight(selected ? .semibold : .regular)).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? color : .primary)
            .glassCapsule(tint: selected ? color : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A screen's sub-sections as a row of glass chips (Panchang and Journey).
/// The pages below also change with a swipe; the row keeps the selected
/// chip in view.
struct SectionChips<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    let identifier: (Item) -> String

    init(_ items: [Item], selection: Binding<Item>, title: @escaping (Item) -> String,
         identifier: @escaping (Item) -> String) {
        self.items = items
        self._selection = selection
        self.title = title
        self.identifier = identifier
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(items, id: \.self) { item in
                            GlassChip(title: title(item), selected: selection == item) {
                                withAnimation(.snappy) { selection = item }
                            }
                            .id(item)
                            .accessibilityIdentifier(identifier(item))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection) { _, value in
                withAnimation { proxy.scrollTo(value, anchor: .center) }
            }
        }
    }
}

/// A section heading with an optional subtitle.
struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.bold))
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small coloured status pill.
struct StatusPill: View {
    let text: String
    var systemImage: String?
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(text).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.35)))
    }
}

/// A stable, restrained surface for the opt-in appearance. The low-strength
/// standard blur leaves the page visible instead of inheriting the OS version's
/// adaptive regular-glass frost. Text is never faded with its background.
struct ClearGlassSurface<S: InsettableShape>: View {
    let shape: S
    var tint: Color? = nil
    var sheet = false
    var border = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if sheet { Color.pageBackground(scheme).opacity(0.88) }
            shape.fill(.ultraThinMaterial).opacity(scheme == .dark ? 0.10 : 0.18)
            shape.fill(LinearGradient(colors: scheme == .dark
                ? [.white.opacity(0.018), .black.opacity(0.06)]
                : [.white.opacity(0.24), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let tint { shape.fill(tint.opacity(0.08)) }
        }
        .clipShape(shape)
        .overlay {
            if border {
                shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(scheme == .dark ? 0.18 : 0.7),
                    Theme.teal.opacity(0.10), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GlassPanelAppearance: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool
    @Environment(\.glassLookEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if GlassLookPolicy.isActive(preference: enabled, reduceTransparency: reduceTransparency) {
            content.background(ClearGlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint))
        } else {
            content.legacyGlassPanel(cornerRadius: cornerRadius, tint: tint, interactive: interactive)
        }
    }
}

private struct GlassCapsuleAppearance: ViewModifier {
    let tint: Color?
    let interactive: Bool
    @Environment(\.glassLookEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if GlassLookPolicy.isActive(preference: enabled, reduceTransparency: reduceTransparency) {
            content.background(ClearGlassSurface(shape: Capsule(), tint: tint))
        } else {
            content.legacyGlassCapsule(tint: tint, interactive: interactive)
        }
    }
}

private struct GlassActionAppearance: ViewModifier {
    let prominent: Bool
    @Environment(\.glassLookEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if GlassLookPolicy.isActive(preference: enabled, reduceTransparency: reduceTransparency) {
            content.buttonStyle(ClearGlassActionStyle(prominent: prominent))
        } else if prominent {
            content.legacyPrimaryActionStyle()
        } else {
            content.legacySecondaryActionStyle()
        }
    }
}

private struct ClearGlassActionStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.tint))
            .background {
                if prominent { Capsule().fill(Theme.teal.opacity(0.95)) }
            }
            .background(ClearGlassSurface(shape: Capsule()))
            .opacity(enabled ? 1 : 0.5)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct GlassSheetAppearance: ViewModifier {
    @Environment(\.glassLookEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if GlassLookPolicy.isActive(preference: enabled, reduceTransparency: reduceTransparency) {
            content.presentationBackground { ClearGlassSurface(shape: Rectangle(), sheet: true, border: false) }
        } else { content.presentationBackground(.thinMaterial) }
    }
}

private struct GlassListAppearance: ViewModifier {
    @Environment(\.glassLookEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if GlassLookPolicy.isActive(preference: enabled, reduceTransparency: reduceTransparency) {
            content.listRowBackground(ClearGlassSurface(shape: Rectangle(), border: false))
        } else { content }
    }
}

private struct GlassToolbarAppearance: ViewModifier {
    @Environment(\.glassLookEnabled) private var enabled
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if GlassLookPolicy.isActive(preference: enabled, reduceTransparency: reduceTransparency) {
            content.buttonStyle(.plain).foregroundStyle(Theme.teal)
                .frame(width: 40, height: 40)
                .background(ClearGlassSurface(shape: Circle()))
        } else { content }
    }
}
