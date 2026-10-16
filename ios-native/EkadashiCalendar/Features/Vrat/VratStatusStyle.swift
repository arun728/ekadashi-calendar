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
        case .observed: return AppSymbol.statusObserved
        case .partial: return AppSymbol.statusPartial
        case .missed: return AppSymbol.statusMissed
        case .unrecorded: return AppSymbol.statusUnrecorded
        }
    }

    /// The home card's record button.
    var cardSymbol: String {
        switch status {
        case .observed: return AppSymbol.cardObserved
        case .partial: return AppSymbol.statusPartial
        case .missed: return AppSymbol.statusMissed
        case .unrecorded: return AppSymbol.cardUnrecorded
        }
    }

    var listKey: String { status == .unrecorded ? "not_recorded" : status.rawValue }
    var detailKey: String { status == .unrecorded ? "record_observance" : status.rawValue }
}
