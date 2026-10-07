import SwiftUI

/// Liquid Glass on iOS 26 (Apple's `glassEffect`), system materials before.
/// Built with Xcode 26; older compilers use the material fallback only.
extension View {
    /// A translucent glass panel (cards, sections).
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = false) -> some View {
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
    func glassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
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
    func primaryActionStyle() -> some View {
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
    func secondaryActionStyle() -> some View {
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

    var body: some View {
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
