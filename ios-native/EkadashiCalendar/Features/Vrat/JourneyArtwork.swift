import SwiftUI
import EkadashiCore

/// Original resolution-independent badge artwork. Controls continue using
/// AppSymbol; these paths are illustrations, not system glyph substitutions.
struct JourneyBadgeArt: View {
    let definition: JourneyBadgeDefinition
    var earned = true
    private var accent: Color { definition.year == 2027 ? Theme.amber : Theme.teal }

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height)
            var c = context
            c.translateBy(x: (size.width - unit) / 2, y: (size.height - unit) / 2)
            c.scaleBy(x: unit / 100, y: unit / 100)
            let ink = earned ? accent : Color.secondary.opacity(0.55)
            let circle = Path(ellipseIn: CGRect(x: 5, y: 5, width: 90, height: 90))
            c.fill(circle, with: .linearGradient(Gradient(colors: [ink.opacity(0.23), ink.opacity(0.04)]),
                                                startPoint: CGPoint(x: 20, y: 0), endPoint: CGPoint(x: 80, y: 100)))
            c.stroke(circle, with: .color(ink.opacity(0.7)), lineWidth: 1)
            c.stroke(Path(ellipseIn: CGRect(x: 10, y: 10, width: 80, height: 80)),
                     with: .color(ink.opacity(0.5)), style: StrokeStyle(lineWidth: 0.8, dash: [1, 4]))
            func line(_ points: [CGPoint], width: CGFloat = 1.8) {
                var p = Path(); p.addLines(points)
                c.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func petal(_ x: CGFloat, _ y: CGFloat, _ angle: Double, length: CGFloat = 29) {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: 0, y: -length), control: CGPoint(x: -12, y: -length * 0.55))
                p.addQuadCurve(to: .zero, control: CGPoint(x: 12, y: -length * 0.55))
                let transform = CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: x, y: y))
                p = p.applying(transform)
                c.fill(p, with: .color(ink.opacity(0.22)))
                c.stroke(p, with: .color(ink), lineWidth: 1.4)
            }
            func flame(_ x: CGFloat, _ y: CGFloat, scale: CGFloat = 1) {
                var p = Path(); p.move(to: CGPoint(x: 0, y: 5))
                p.addCurve(to: CGPoint(x: 0, y: -20), control1: CGPoint(x: -15, y: 0), control2: CGPoint(x: -3, y: -12))
                p.addCurve(to: CGPoint(x: 0, y: 5), control1: CGPoint(x: 2, y: -11), control2: CGPoint(x: 14, y: -2))
                p = p.applying(CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: x, y: y)))
                c.fill(p, with: .color(ink.opacity(0.4))); c.stroke(p, with: .color(ink), lineWidth: 1.5)
            }
            switch definition.art {
            case .lamp:
                flame(50, 45)
                var bowl = Path(); bowl.move(to: CGPoint(x: 27, y: 53))
                bowl.addQuadCurve(to: CGPoint(x: 73, y: 53), control: CGPoint(x: 50, y: 88))
                bowl.closeSubpath(); c.fill(bowl, with: .color(ink.opacity(0.2))); c.stroke(bowl, with: .color(ink), lineWidth: 1.8)
                line([CGPoint(x: 38, y: 76), CGPoint(x: 62, y: 76)])
            case .leaves:
                line([CGPoint(x: 50, y: 77), CGPoint(x: 50, y: 32)])
                petal(50, 62, -0.8, length: 25); petal(50, 50, 0.8, length: 26); petal(50, 38, 0, length: 17)
            case .lotus, .petals, .annual:
                let count = definition.art == .petals ? 3 : 7
                for i in 0..<count { petal(50, 65, Double(i - count / 2) * 0.33, length: i == count / 2 ? 39 : 33) }
                line([CGPoint(x: 30, y: 72), CGPoint(x: 70, y: 72)])
                if definition.art == .annual {
                    for i in 0..<12 {
                        let a = Double(i) * .pi / 6
                        let p = CGPoint(x: 50 + cos(a) * 34, y: 49 + sin(a) * 34)
                        c.fill(Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)), with: .color(ink))
                    }
                }
            case .lights:
                for i in 0..<12 {
                    let a = Double(i) * .pi / 6
                    flame(50 + cos(a) * 24, 51 + sin(a) * 24, scale: 0.36)
                }
                c.stroke(Path(ellipseIn: CGRect(x: 38, y: 38, width: 24, height: 24)), with: .color(ink), lineWidth: 1)
            case .flame: flame(50, 64, scale: 1.8)
            case .arcs:
                for i in 0..<3 {
                    var p = Path(); p.addArc(center: CGPoint(x: 50, y: 56), radius: CGFloat(15 + i * 9),
                                           startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
                    c.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                c.fill(Path(ellipseIn: CGRect(x: 46, y: 63, width: 8, height: 8)), with: .color(ink))
            case .thread:
                for i in 0..<3 {
                    var p = Path(); p.addEllipse(in: CGRect(x: 29 + i * 3, y: 23 + i * 4, width: 38, height: 48))
                    c.stroke(p, with: .color(ink.opacity(0.85)), style: StrokeStyle(lineWidth: 2, dash: [7, 3]))
                }
            case .wreath:
                for side in [-1.0, 1.0] {
                    for i in 0..<6 {
                        let angle = Double(i) * 0.28
                        petal(50 + side * sin(angle + 0.3) * 26, 77 - CGFloat(i) * 8,
                              side * (0.5 + angle), length: 14)
                    }
                }
                flame(50, 54)
            case .sunrise:
                var p = Path(); p.addArc(center: CGPoint(x: 50, y: 58), radius: 19,
                                       startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                c.stroke(p, with: .color(ink), lineWidth: 2)
                line([CGPoint(x: 24, y: 59), CGPoint(x: 76, y: 59)])
                line([CGPoint(x: 34, y: 68), CGPoint(x: 66, y: 68)])
                for i in 0..<5 {
                    let a = Double(i) * .pi / 4
                    line([CGPoint(x: 50 + cos(a) * 24, y: 58 - sin(a) * 24),
                          CGPoint(x: 50 + cos(a) * 30, y: 58 - sin(a) * 30)])
                }
            case .quarter:
                for i in 0..<4 {
                    petal(50, 50, Double(i) * .pi / 2, length: 30)
                }
                let q = definition.quarter ?? 1
                let a = Double(q - 1) * .pi / 2 - .pi / 2
                c.fill(Path(ellipseIn: CGRect(x: 46 + cos(a) * 20, y: 46 + sin(a) * 20, width: 8, height: 8)), with: .color(ink))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct JourneyMandala: View {
    @Environment(AppModel.self) private var model
    let progress: JourneyYear

    var body: some View {
        ZStack {
            Canvas { context, size in
                let side = min(size.width, size.height), center = CGPoint(x: size.width / 2, y: size.height / 2)
                let inner = side * 0.29, outer = side * 0.45
                let count = max(1, progress.segments.count)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - inner + 5, y: center.y - inner + 5,
                                                      width: inner * 2 - 10, height: inner * 2 - 10)),
                               with: .color(Theme.teal.opacity(0.2)), lineWidth: 1)
                for (index, segment) in progress.segments.enumerated() {
                    let angle = Double(index) / Double(count) * .pi * 2 - .pi / 2
                    let half = .pi / Double(count) * 0.78
                    func point(_ r: CGFloat, _ a: Double) -> CGPoint { CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r) }
                    var petal = Path(); petal.move(to: point(inner, angle - half))
                    petal.addQuadCurve(to: point(outer, angle), control: point(outer * 0.95, angle - half))
                    petal.addQuadCurve(to: point(inner, angle + half), control: point(outer * 0.95, angle + half))
                    petal.addQuadCurve(to: point(inner, angle - half), control: point(inner * 0.83, angle))
                    let observed = !segment.isFuture && segment.status == .observed
                    let partial = !segment.isFuture && segment.status == .partial
                    let color = observed ? Theme.teal : partial ? Theme.partial : Color.secondary
                    if observed || partial {
                        context.fill(petal, with: .linearGradient(Gradient(colors: [color.opacity(0.2), color.opacity(0.85)]),
                                                                 startPoint: point(inner, angle), endPoint: point(outer, angle)))
                    }
                    context.stroke(petal, with: .color(color.opacity(segment.isFuture ? 0.2 : 0.7)),
                                   style: StrokeStyle(lineWidth: 1.3, dash: segment.status == .unrecorded && !segment.isFuture ? [2, 3] : []))
                    if partial {
                        var clipped = context; clipped.clip(to: petal)
                        for offset in stride(from: -side, through: side, by: 6) {
                            var line = Path(); line.move(to: CGPoint(x: center.x + offset, y: 0))
                            line.addLine(to: CGPoint(x: center.x + offset + side, y: side))
                            clipped.stroke(line, with: .color(Color.white.opacity(0.65)), lineWidth: 1)
                        }
                    }
                    if !segment.isFuture && segment.status == .missed {
                        let dot = point((inner + outer) / 2, angle)
                        var mark = Path(); mark.move(to: CGPoint(x: dot.x - 2, y: dot.y - 2)); mark.addLine(to: CGPoint(x: dot.x + 2, y: dot.y + 2))
                        mark.move(to: CGPoint(x: dot.x - 2, y: dot.y + 2)); mark.addLine(to: CGPoint(x: dot.x + 2, y: dot.y - 2))
                        context.stroke(mark, with: .color(color), lineWidth: 1.2)
                    }
                }
                for quarter in progress.quarters {
                    let angle = Double(quarter.id - 1) * .pi / 2 - .pi / 2
                    let p = CGPoint(x: center.x + cos(angle) * side * 0.485, y: center.y + sin(angle) * side * 0.485)
                    let ornament = Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
                    if quarter.completed { context.fill(ornament, with: .color(Theme.amber)) }
                    else { context.stroke(ornament, with: .color(Theme.teal.opacity(0.25)), lineWidth: 1) }
                }
            }
            VStack(spacing: 2) {
                if progress.annualBonus > 0, let badge = JourneyBadgeCatalog.definition("journey_\(progress.year)_full") {
                    JourneyBadgeArt(definition: badge).frame(width: 64, height: 64)
                }
                Text(String(progress.year)).font(.title2.weight(.semibold)).foregroundStyle(Theme.teal).lineLimit(1).minimumScaleFactor(0.5)
                Text("\(progress.observed) / \(progress.segments.count)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.t("ios_journey_mandala"))
        .accessibilityValue(model.t("ios_journey_mandala_summary", "\(progress.segments.count)", "\(progress.observed)", "\(progress.partial)"))
        .accessibilityIdentifier("journey_mandala")
    }
}
