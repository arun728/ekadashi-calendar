import SwiftUI
import EkadashiCore

/// Choose which Google calendars to import (google_calendar_picker_sheet.dart).
struct GoogleCalendarPickerView: View {
    @Environment(AppModel.self) private var model
    let request: GooglePickerRequest
    @State private var chosen: Set<String> = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(model.t("choose_calendars_help")).font(.footnote).foregroundStyle(.secondary)
                    if let email = request.email {
                        HStack {
                            Label(email, systemImage: "person.crop.circle").font(.subheadline).lineLimit(1)
                            Spacer()
                            Button(model.t("switch_google_account")) { model.pickerFinished(.switchAccount) }
                                .font(.subheadline)
                        }
                    }
                }
                Section {
                    ForEach(request.calendars) { calendar in
                        Toggle(isOn: binding(calendar.id)) {
                            VStack(alignment: .leading) {
                                Text(calendar.summary)
                                if calendar.primary { Text(model.t("primary_calendar")).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        .tint(Theme.googleBlue)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(model.t("choose_calendars"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.t("cancel")) { model.pickerFinished(.cancelled) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    model.pickerFinished(.chosen(request.calendars.map(\.id).filter(chosen.contains)))
                } label: {
                    Text(model.t("import_selected")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .primaryActionStyle()
                .disabled(chosen.isEmpty)
                .padding()
                .accessibilityIdentifier("import_selected")
            }
        }
        .presentationBackground(.thinMaterial)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            // "primary" stands for the account's primary calendar.
            let saved = Set(request.saved)
            chosen = Set(request.calendars.filter { saved.contains($0.id) || ($0.primary && saved.contains("primary")) }.map(\.id))
            if chosen.isEmpty, let primary = request.calendars.first(where: \.primary) { chosen = [primary.id] }
        }
    }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { chosen.contains(id) }, set: { on in
            if on { chosen.insert(id) } else { chosen.remove(id) }
        })
    }
}
