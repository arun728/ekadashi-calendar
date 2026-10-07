import SwiftUI

/// A short floating message with at most one action (the Android snackbar).
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var actionTitle: String?
    var action: (() -> Void)?

    static func == (a: ToastMessage, b: ToastMessage) -> Bool { a.id == b.id }
}

struct ToastOverlay: ViewModifier {
    @Binding var message: ToastMessage?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                HStack(spacing: 12) {
                    Text(message.text).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    if let title = message.actionTitle, let action = message.action {
                        Button(title) {
                            self.message = nil
                            action()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.teal)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .glassPanel(cornerRadius: 18)
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: message.id) {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    if self.message?.id == message.id { withAnimation { self.message = nil } }
                }
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.snappy, value: message)
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View { modifier(ToastOverlay(message: message)) }
}
