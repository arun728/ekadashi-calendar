import SwiftUI
import Photos
import EkadashiCore

/// Preview of an Ekadashi share card with Share (image and a message with
/// the store links) and Save to Photos. Free: no paywall.
struct ShareCardSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let event: EkadashiOccurrence
    @State private var image: UIImage?
    @State private var status: String?
    @State private var saving = false

    private var content: ShareCardContent { ShareCardContent(event: event, model: model) }

    private var message: String {
        AppLinks.shareCardMessage(model.t("share_card_message", event.name, model.fullDate(event.date)),
                                  appStoreId: Bundle.main.object(forInfoDictionaryKey: "EkadashiAppStoreId") as? String ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    EkadashiShareCard(content: content)
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("share_card_preview")
                    if let image {
                        GlassGroup {
                            HStack(spacing: 10) {
                                Button {
                                    Task { await save(image) }
                                } label: {
                                    Label(model.t("ios_share_card_save"), systemImage: AppSymbol.save)
                                        .font(.callout.bold()).frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                                .secondaryActionStyle()
                                .disabled(saving)
                                .accessibilityIdentifier("share_card_save")
                                ShareLink(item: Image(uiImage: image), message: Text(message),
                                          preview: SharePreview(event.name, image: Image(uiImage: image))) {
                                    Label(model.t("share"), systemImage: AppSymbol.share)
                                        .font(.callout.bold()).frame(maxWidth: .infinity).padding(.vertical, 6)
                                }
                                .primaryActionStyle()
                                .accessibilityIdentifier("share_card_share")
                            }
                        }
                    } else {
                        ProgressView(model.t("share_card_preparing")).tint(Theme.teal)
                    }
                    if let status {
                        Text(status).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle(model.t("share_card_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppToolbarItem(placement: .cancellationAction) { Button(model.t("cancel")) { dismiss() } }
            }
        }
        .task { render() }
    }

    private func render() {
        let renderer = ImageRenderer(content: EkadashiShareCard(content: content))
        renderer.scale = max(displayScale, 3)
        image = renderer.uiImage
    }

    /// Adds the card to Photos (add-only access).
    private func save(_ image: UIImage) async {
        saving = true
        defer { saving = false }
        let access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard access == .authorized || access == .limited else {
            status = model.t("ios_share_card_photos_denied")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) }
            status = model.t("ios_share_card_saved")
        } catch {
            status = model.t("share_card_save_failed")
        }
    }
}
