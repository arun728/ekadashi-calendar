import SwiftUI
import EkadashiCore

/// The "Festivals and events" part of Notifications (docs/ROADMAP.md
/// Phase 7): the user's reminders and a button to add one. Festival and
/// Panchang reminders are Premium (like Key days); reminders for the user's
/// own and Google entries are free.
struct EventReminderRows: View {
    @Environment(AppModel.self) private var model
    let enabled: Bool
    /// Owned by the screen: a sheet on a List row is dismissed when the row is recycled.
    @Binding var editing: EditorRequest?

    struct EditorRequest: Identifiable {
        let reminder: EventReminder?
        var id: String { reminder?.id ?? "new" }
    }

    var body: some View {
        let reminders = model.eventReminders.reminders
        Group {
            if reminders.isEmpty {
                Text(model.t("notifications_no_events")).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(reminders) { reminder in
                Button { editing = EditorRequest(reminder: reminder) } label: { row(reminder) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("event_reminder_row_\(reminder.id)")
                    .swipeActions {
                        Button(role: .destructive) { delete(reminder) } label: {
                            Label(model.t("notifications_delete_event"), systemImage: "trash")
                        }
                    }
            }
            Button { editing = EditorRequest(reminder: nil) } label: {
                Label(model.t("notifications_add_event"), systemImage: "plus.circle.fill")
                    .foregroundStyle(Theme.teal)
            }
            .accessibilityIdentifier("notifications_add_event")
        }
        .disabled(!enabled)
    }

    private func row(_ reminder: EventReminder) -> some View {
        let locked = reminder.target.requiresPremium && !model.premium.isPremium
        return HStack(spacing: 12) {
            Image(systemName: symbol(reminder.target)).foregroundStyle(Theme.teal).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(EventReminderChoice.title(reminder.target, language: model.language)).foregroundStyle(.primary)
                Text(EventReminderText.summary(reminder, model: model)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if locked {
                Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel(model.t("search_premium_locked"))
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func symbol(_ target: EventReminderTarget) -> String {
        switch target {
        case .observance: return "sparkles"
        case .calendar(.google): return "g.circle"
        case .calendar: return "calendar"
        }
    }

    private func delete(_ reminder: EventReminder) {
        var settings = model.eventReminders
        settings.remove(reminder.target)
        model.updateEventReminders(settings)
    }
}

/// Lead times and the time of day, in the app language.
enum EventReminderText {
    @MainActor
    static func lead(_ days: Int, model: AppModel) -> String {
        switch days {
        case 0: return model.t("notifications_lead_0")
        case 1: return model.t("notifications_lead_1")
        default: return model.t("notifications_lead_n", String(days))
        }
    }

    @MainActor
    static func time(hour: Int, minute: Int, model: AppModel) -> String {
        let formatter = DateFormatter()
        formatter.locale = model.locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour, minute: minute)) ?? Date()
        return formatter.string(from: date)
    }

    /// "1 day before, 2 days before · 7:00 AM".
    @MainActor
    static func summary(_ reminder: EventReminder, model: AppModel) -> String {
        let days = reminder.daysBefore.map { lead($0, model: model) }.joined(separator: ", ")
        return "\(days) · \(time(hour: reminder.hour, minute: reminder.minute, model: model))"
    }
}

/// Adds or edits one reminder: the event, the days before and the time.
struct EventReminderEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let original: EventReminder?
    @State private var target: EventReminderTarget?
    @State private var days: Set<Int>
    @State private var time: Date
    @State private var showPaywall = false

    init(original: EventReminder?) {
        self.original = original
        let reminder = original ?? EventReminder(target: .calendar(.custom))
        _target = State(initialValue: original?.target)
        _days = State(initialValue: Set(reminder.daysBefore))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        _time = State(initialValue: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: reminder.hour,
                                                                        minute: reminder.minute)) ?? Date())
    }

    private var locked: Bool { target?.requiresPremium == true && !model.premium.isPremium }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        EventReminderPicker(selection: $target)
                    } label: {
                        LabeledContent(model.t("notifications_choose_event")) {
                            Text(target.map { EventReminderChoice.title($0, language: model.language) } ?? "—")
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .accessibilityIdentifier("event_reminder_choose")
                }

                Section {
                    ForEach(EventReminder.leadDays, id: \.self) { lead in
                        Button { toggle(lead) } label: {
                            HStack {
                                Text(EventReminderText.lead(lead, model: model)).foregroundStyle(.primary)
                                Spacer()
                                if days.contains(lead) {
                                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Theme.teal)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("event_reminder_lead_\(lead)")
                        .accessibilityAddTraits(days.contains(lead) ? .isSelected : [])
                    }
                } header: {
                    Text(model.t("notifications_lead_title"))
                } footer: {
                    if days.isEmpty { Text(model.t("notifications_lead_required")).foregroundStyle(.orange) }
                }

                Section {
                    DatePicker(model.t("notifications_time"), selection: $time, displayedComponents: .hourAndMinute)
                        .tint(Theme.teal)
                }

                if locked {
                    Section {
                        Label(model.t("notifications_premium_events"), systemImage: "lock.fill")
                            .font(.subheadline)
                        Button(model.t("premium_upgrade")) { showPaywall = true }
                            .foregroundStyle(Theme.teal)
                            .accessibilityIdentifier("event_reminder_upgrade")
                    }
                }

                if let original {
                    Section {
                        Button(role: .destructive) {
                            var settings = model.eventReminders
                            settings.remove(original.target)
                            model.updateEventReminders(settings)
                            dismiss()
                        } label: {
                            Text(model.t("notifications_delete_event")).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(model.t(original == nil ? "notifications_add_event" : "notifications_edit_event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.t("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.t("save")) { save() }
                        .disabled(target == nil || days.isEmpty)
                        .accessibilityIdentifier("event_reminder_save")
                }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationStack { PremiumView(reason: nil) }
            }
        }
    }

    private func toggle(_ lead: Int) {
        if days.contains(lead) { days.remove(lead) } else { days.insert(lead) }
    }

    /// Saves even while locked: the reminder starts with Premium.
    private func save() {
        guard let target else { return }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var settings = model.eventReminders
        if let original, original.target != target { settings.remove(original.target) }
        settings.upsert(EventReminder(target: target, daysBefore: Array(days), hour: parts.hour ?? 7, minute: parts.minute ?? 0))
        model.updateEventReminders(settings)
        dismiss()
    }
}

/// Festivals (alphabetical), monthly days and the user's calendars, with a
/// search field. Premium choices carry a lock for free users.
struct EventReminderPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: EventReminderTarget?
    @State private var query = ""

    var body: some View {
        let choices = filtered(EventReminderChoice.all(language: model.language))
        List {
            ForEach(EventReminderChoice.Kind.allCases, id: \.self) { group in
                let items = choices.filter { $0.group == group }
                if !items.isEmpty {
                    Section(model.t(group.titleKey)) {
                        ForEach(items) { choice in
                            Button {
                                selection = choice.target
                                dismiss()
                            } label: {
                                HStack {
                                    Text(choice.title).foregroundStyle(.primary)
                                    Spacer()
                                    if selection == choice.target {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.teal)
                                    } else if choice.requiresPremium && !model.premium.isPremium {
                                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("event_choice_\(choice.id)")
                        }
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: model.t("notifications_search_events"))
        .navigationTitle(model.t("notifications_choose_event"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Matches the title in the app language or in English, ignoring accents and case.
    private func filtered(_ choices: [EventReminderChoice]) -> [EventReminderChoice] {
        let needle = SearchText.normalize(query)
        guard !needle.isEmpty else { return choices }
        return choices.filter { choice in
            SearchText.normalize(choice.title).contains(needle)
                || SearchText.normalize(EventReminderChoice.title(choice.target, language: "en")).contains(needle)
        }
    }
}
