import SwiftUI
import EkadashiCore

struct EntryEditorRequest: Identifiable {
    let id = UUID()
    let day: CivilDate
    let existing: CalendarEntry?
}

/// Add or edit a custom entry (add_edit_entry_sheet.dart). Custom entries
/// are free.
struct EntryEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let request: EntryEditorRequest

    @State private var title = ""
    @State private var notes = ""
    @State private var allDay = false
    @State private var start = Date()
    @State private var end = Date()
    @State private var invalid = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                TextField(model.t("entry_title"), text: $title)
                    .accessibilityIdentifier("entry_title")
                Toggle(model.t("all_day"), isOn: $allDay).tint(Theme.teal)
                DatePicker(model.t("entry_starts"), selection: $start,
                           displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                    .environment(\.locale, model.timePickerLocale)
                DatePicker(model.t("entry_ends"), selection: $end, in: start...,
                           displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                    .environment(\.locale, model.timePickerLocale)
                TextField(model.t("entry_notes"), text: $notes, axis: .vertical).lineLimit(2...5)
                if invalid {
                    Text(model.t("invalid_entry")).foregroundStyle(.red).font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(model.t(request.existing == nil ? "add_entry" : "edit_entry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(model.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.t("save"), action: save).bold().accessibilityIdentifier("save_entry")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.thinMaterial)
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let entry = request.existing {
            title = entry.title
            notes = entry.notes ?? ""
            allDay = entry.isAllDay
            let interval = entry.interval(in: .current)
            start = interval.0
            // All-day ends are exclusive; the picker shows the last day.
            end = entry.isAllDay ? Calendar.current.date(byAdding: .day, value: -1, to: interval.1) ?? interval.1 : interval.1
        } else {
            var calendar = Calendar.current
            calendar.timeZone = .current
            let day = calendar.date(from: DateComponents(year: request.day.year, month: request.day.month, day: request.day.day,
                                                         hour: 9)) ?? Date()
            start = day
            end = day.addingTimeInterval(3600)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, end >= start else {
            invalid = true
            return
        }
        var storedStart = start, storedEnd = end
        if allDay {
            // All-day entries are stored as UTC midnights with an exclusive end, like Google's.
            let first = CivilDate.today(in: .current, now: start), last = CivilDate.today(in: .current, now: end)
            storedStart = first.utcMidnight
            storedEnd = max(last, first).adding(days: 1).utcMidnight
        }
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = CalendarEntry(id: request.existing?.id ?? "custom_\(UUID().uuidString)", title: trimmed,
                                  notes: note.isEmpty ? nil : note, start: storedStart, end: storedEnd, isAllDay: allDay,
                                  source: .custom, updatedAt: Date())
        do {
            try model.entries.upsert(entry)
            model.entriesChanged()
            dismiss()
        } catch {
            model.show("storage_failed")
        }
    }
}
