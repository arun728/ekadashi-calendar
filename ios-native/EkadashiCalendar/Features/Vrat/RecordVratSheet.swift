import SwiftUI
import EkadashiCore

/// Record or edit one observance (record_vrat_dialog.dart). The first three
/// recorded entries are free; a fourth new entry opens the paywall, while
/// existing entries stay editable.
struct RecordVratSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let event: EkadashiOccurrence

    @State private var status: ObservanceStatus = .observed
    @State private var method: FastingMethod = .fullFast
    @State private var methodOther = ""
    @State private var note = ""
    @State private var existing: VratRecord?
    @State private var confirmDelete = false
    @State private var loaded = false
    @State private var saving = false
    @State private var paywallOpen = false
    @State private var toast: ToastMessage?

    /// Device calendar day, as the Android dialog.
    private var isFuture: Bool { event.date > CivilDate.today() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name).font(.title3.bold())
                        Text(model.format(event.date, "EEEE, d MMMM yyyy")).font(.footnote).foregroundStyle(.secondary)
                    }
                    if isFuture {
                        Label(model.t("cannot_record_future"), systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    label("status_active")
                    GlassGroup(spacing: 8) {
                        HStack(spacing: 8) {
                            statusChip(.observed, "observed", "checkmark.circle")
                            statusChip(.partial, "partial", "circle.circle")
                            statusChip(.missed, "missed", "xmark.circle")
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("vrat_record_status_tube")
                    if status == .observed || status == .partial {
                        label("fasting_method")
                        FlowLayout(spacing: 8) {
                            ForEach(FastingMethod.allCases, id: \.self) { item in
                                GlassChip(title: model.t(item.localizationKey), selected: method == item) { method = item }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("vrat_fasting_method_tube")
                        if method == .other {
                            TextField(model.t("method_other_hint"), text: $methodOther)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    label("notes")
                    TextField(model.t("notes_hint"), text: $note, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task { await save() }
                    } label: {
                        Text(model.t(existing != nil ? "edit_record" : "record_observance"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .primaryActionStyle()
                    .disabled(saving)
                    .accessibilityIdentifier("vrat_record_save")
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.t("cancel")) { dismiss() }
                }
                if existing != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }
                        .accessibilityLabel(model.t("delete_record"))
                    }
                }
            }
            .alert(model.t("delete_confirm"), isPresented: $confirmDelete) {
                Button(model.t("cancel"), role: .cancel) {}
                Button(model.t("delete_record"), role: .destructive) { delete() }
            } message: {
                Text(model.t("delete_confirm_desc"))
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.thinMaterial)
        .onAppear(perform: load)
        // A sheet cannot be presented from the root while this one is up,
        // so the paywall opens from here.
        .sheet(isPresented: $paywallOpen, onDismiss: paywallClosed) {
            NavigationStack { PremiumView(reason: "vrat_free_limit_reached") }
        }
        .toast($toast)
    }

    private func label(_ key: String) -> some View {
        Text(model.t(key)).font(.footnote.weight(.semibold)).foregroundStyle(Theme.teal)
    }

    private func statusChip(_ value: ObservanceStatus, _ key: String, _ symbol: String) -> some View {
        GlassChip(title: model.t(key), systemImage: symbol, color: VratStatusStyle(value).color, selected: status == value) {
            if isFuture {
                show("cannot_record_future")
            } else {
                status = value
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        existing = model.vrat.record(for: event.occurrenceUid)
        status = existing?.status ?? (isFuture ? .unrecorded : .observed)
        method = existing?.fastingMethod ?? .fullFast
        methodOther = existing?.fastingMethodOther ?? ""
        note = existing?.note ?? ""
    }

    private func show(_ key: String) { toast = ToastMessage(text: model.t(key)) }

    private func save() async {
        if isFuture {
            show("cannot_record_future")
            return
        }
        if status != .unrecorded && model.vrat.needsPremium(uid: event.occurrenceUid, premium: model.premium.isPremium) {
            paywallOpen = true
            return
        }
        write()
    }

    private func paywallClosed() {
        if model.premium.isPremium {
            write()
        } else {
            show("vrat_free_limit_reached")
        }
    }

    private func write() {
        saving = true
        defer { saving = false }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let unlocked = try model.vrat.save(
                event, status: status,
                method: status == .observed || status == .partial ? method : nil,
                methodOther: method == .other ? methodOther.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                timezone: model.timezone.rawValue, occurrences: model.ekadashis)
            dismiss()
            model.announce(unlocked, afterDismissal: true)
        } catch {
            show("tracker_storage_failed")
        }
    }

    private func delete() {
        do {
            try model.vrat.delete(event, occurrences: model.ekadashis)
            dismiss()
        } catch {
            show("tracker_storage_failed")
        }
    }
}

/// Wraps chips onto as many lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let addition = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += addition
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
