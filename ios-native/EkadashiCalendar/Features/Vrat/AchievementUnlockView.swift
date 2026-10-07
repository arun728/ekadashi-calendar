import SwiftUI
import EkadashiCore

/// "Achievement unlocked" (achievement_unlock_dialog.dart).
struct AchievementUnlockView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 40))
                .foregroundStyle(Theme.teal)
                .frame(width: 88, height: 88)
                .glassPanel(cornerRadius: 44, tint: Theme.teal)
                .symbolEffect(.bounce, value: achievement.id)
            Text(model.t("achievement_unlocked")).font(.caption.weight(.bold)).foregroundStyle(Theme.teal).textCase(.uppercase)
            Text(model.t(achievement.titleKey)).font(.title2.bold()).multilineTextAlignment(.center)
            Text(model.t(achievement.descriptionKey)).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text(model.t("hari_om")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .primaryActionStyle()
        }
        .padding(28)
        .presentationBackground(.thinMaterial)
        .sensoryFeedback(.success, trigger: achievement.id)
    }
}
