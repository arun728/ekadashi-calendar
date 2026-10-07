import SwiftUI
import EkadashiCore

/// The home tab: location and language, then one card per Ekadashi with
/// arrows, opening on the current or next Ekadashi (main.dart home).
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HomeHeader()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
            if model.ekadashis.isEmpty {
                ContentUnavailableView(model.t("no_ekadashi"), systemImage: "calendar.badge.exclamationmark")
            } else {
                Text("\(model.homeIndex + 1) / \(model.ekadashis.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("home_page_indicator")
                HStack(spacing: 0) {
                    arrow("chevron.left", target: model.homeIndex - 1) { model.homeIndex -= 1 }
                    TabView(selection: $model.homeIndex) {
                        ForEach(Array(model.ekadashis.enumerated()), id: \.element.id) { index, event in
                            EkadashiCard(event: event)
                                .padding(4)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    arrow("chevron.right", target: model.homeIndex + 1) { model.homeIndex += 1 }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
                .animation(.easeInOut(duration: 0.3), value: model.homeIndex)
            }
        }
    }

    /// An arrow to the card at [target], read out as that Ekadashi's name.
    private func arrow(_ symbol: String, target: Int, action: @escaping () -> Void) -> some View {
        let enabled = model.ekadashis.indices.contains(target)
        return Button(action: action) {
            Image(systemName: symbol).font(.system(size: 28, weight: .semibold))
                .frame(width: 40, height: 60)
        }
        .disabled(!enabled)
        .foregroundStyle(enabled ? Theme.teal : .gray)
        .accessibilityLabel(enabled ? model.ekadashis[target].name : "")
    }
}

/// Location (tap to refresh or to re-ask) and the language menu, in one glass tube.
struct HomeHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                location.frame(maxWidth: .infinity, alignment: .leading)
                LanguageMenu()
            }
            VStack(alignment: .leading, spacing: 8) {
                location
                LanguageMenu().frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCapsule(interactive: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home_options_tube")
    }

    @ViewBuilder
    private var location: some View {
        switch model.locationState {
        case .detecting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.teal)
                Text(model.t("detecting_location")).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        case .denied:
            Button {
                Task { await model.requestLocationAgain() }
            } label: {
                Label(model.t("location_denied"), systemImage: "location.slash")
                    .font(.subheadline).underline().foregroundStyle(.orange).lineLimit(1)
            }
            .buttonStyle(.plain)
        case .located(let city) where !city.isEmpty:
            Button {
                Task { await model.handleLocation() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill").foregroundStyle(Theme.teal)
                    Text("\(city) • \(model.timezone.rawValue)").font(.subheadline.weight(.medium)).lineLimit(1)
                    Image(systemName: "arrow.clockwise").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        default:
            Button {
                Task { await model.handleLocation() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill").foregroundStyle(Theme.teal)
                    Text("\(model.t("locating")) • \(model.timezone.rawValue)").font(.subheadline)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// తెలుగు / English / हिंदी / தமிழ், as on Android.
struct LanguageMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            ForEach(["te", "en", "hi", "ta"], id: \.self) { code in
                Button {
                    model.setLanguage(code)
                } label: {
                    if code == model.language { Label(Localizer.displayName(code), systemImage: "checkmark") } else { Text(Localizer.displayName(code)) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(Localizer.displayName(model.language)).font(.subheadline.weight(.medium))
                Image(systemName: "globe").foregroundStyle(Theme.teal)
            }
        }
        .accessibilityIdentifier("language_menu")
    }
}

/// One Ekadashi: countdown badge, dates, fast and Parana times, the short
/// description, View Details and the Vrat record button.
struct EkadashiCard: View {
    @Environment(AppModel.self) private var model
    let event: EkadashiOccurrence
    @State private var recording = false

    private var daysUntil: Int { model.today.days(until: event.date) }

    private var daysText: String {
        switch daysUntil {
        case 0: return model.t("today")
        case 1: return model.t("tomorrow")
        case ..<0: return model.t("passed")
        default: return model.t("in_days", String(daysUntil))
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(daysText)
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(daysUntil < 0 ? Color.gray : Theme.teal, in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(model.format(event.date, "MMM dd, yyyy")).font(.title2.weight(.light)).padding(.top, 16)
                    Text(model.format(event.date, "EEEE")).font(.callout).foregroundStyle(.secondary).padding(.top, 4)
                    Text(event.name)
                        .font(.title.bold())
                        .foregroundStyle(Theme.teal)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                    timing(model.t("start_fasting"), event.date, event.fastStartTime).padding(.top, 24)
                    timing(model.t("break_fasting"), event.date.adding(days: 1), EkadashiDisplay.breakTime(event))
                        .padding(.top, 16)
                    Divider().padding(.vertical, 16)
                    Text(event.description)
                        .font(.callout.italic())
                        .foregroundStyle(.primary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .scrollIndicators(.hidden)
            GlassGroup {
                HStack(spacing: 8) {
                    NavigationLink {
                        EkadashiDetailsView(event: event)
                    } label: {
                        Text(model.t("view_details")).font(.callout.bold()).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .primaryActionStyle()
                    .accessibilityIdentifier("view_details")
                    if model.vrat.isEnabled {
                        Button {
                            recording = true
                        } label: {
                            Image(systemName: VratStatusStyle(model.vrat.record(for: event.occurrenceUid)?.status).cardSymbol)
                                .font(.title3)
                                .padding(.vertical, 4)
                        }
                        .secondaryActionStyle()
                        .accessibilityLabel(model.t(model.vrat.record(for: event.occurrenceUid) == nil ? "record_vrat" : "edit_record"))
                        .accessibilityIdentifier("home_record_vrat")
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .glassPanel(cornerRadius: 24)
        .sheet(isPresented: $recording) { RecordVratSheet(event: event) }
    }

    private func timing(_ title: String, _ date: CivilDate, _ time: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.callout.bold()).foregroundStyle(Theme.teal)
            Text(model.format(date, "MMM dd, yyyy")).font(.subheadline).foregroundStyle(.secondary)
            Text(time).font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum EkadashiDisplay {
    /// The Parana window without the leading "Mmm d, " the data carries.
    static func breakTime(_ event: EkadashiOccurrence) -> String {
        event.fastBreakTime.replacingOccurrences(of: #"^[a-zA-Z]{3} \d{1,2}, "#, with: "", options: .regularExpression)
    }
}
