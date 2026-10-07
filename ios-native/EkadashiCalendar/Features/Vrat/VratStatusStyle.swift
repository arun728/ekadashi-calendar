import SwiftUI
import EkadashiCore

/// Colour, symbol and label of an observance status, shared by every screen.
struct VratStatusStyle {
    let status: ObservanceStatus

    init(_ status: ObservanceStatus?) { self.status = status ?? .unrecorded }

    var color: Color {
        switch status {
        case .observed: return Theme.observed
        case .partial: return Theme.partial
        case .missed: return Theme.missed
        case .unrecorded: return .gray
        }
    }

    /// Status symbol in lists and the details button.
    var symbol: String {
        switch status {
        case .observed: return "checkmark.circle"
        case .partial: return "circle.circle"
        case .missed: return "xmark.circle"
        case .unrecorded: return "questionmark.circle"
        }
    }

    /// The home card's record button.
    var cardSymbol: String {
        switch status {
        case .observed: return "checkmark.circle.fill"
        case .partial: return "circle.circle"
        case .missed: return "xmark.circle"
        case .unrecorded: return "calendar.badge.plus"
        }
    }

    var listKey: String { status == .unrecorded ? "not_recorded" : status.rawValue }
    var detailKey: String { status == .unrecorded ? "record_observance" : status.rawValue }
}
