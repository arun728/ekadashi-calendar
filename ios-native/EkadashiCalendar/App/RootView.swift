import SwiftUI
import EkadashiCore

/// Five tabs (Today, Calendar, Vrat, Panchang, Settings) with Search in the
/// top bar, as on Android. On iOS 26 the system tab bar and toolbars are
/// Liquid Glass.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: tabSelection) {
            screen(TodayView())
                .tabItem { Label(model.t("home"), systemImage: "house.fill") }
                .tag(AppTab.today)
            screen(CalendarView())
                .tabItem { Label(model.t("calendar"), systemImage: "calendar") }
                .tag(AppTab.calendar)
            screen(VratView())
                .tabItem { Label(model.t("vrat"), systemImage: "leaf") }
                .tag(AppTab.vrat)
            // Panchang is English-only by design.
            screen(PanchangView())
                .tabItem { Label("Panchang", systemImage: "sparkles") }
                .tag(AppTab.panchang)
            screen(SettingsView())
                .tabItem { Label(model.t("settings"), systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Theme.teal)
        .modifier(TabBarMinimize())
        .sheet(isPresented: $model.showSearch) {
            NavigationStack { GlobalSearchView() }
        }
        .sheet(item: $model.paywall, onDismiss: { model.paywallClosed() }) { request in
            NavigationStack { PremiumView(reason: request.reason) }
        }
        .sheet(item: $model.googlePicker, onDismiss: {
            // Swiping the sheet away is the same as closing it.
            model.pickerFinished(.cancelled)
        }) { request in
            GoogleCalendarPickerView(request: request)
        }
        .sheet(item: unlockBinding) { achievement in
            AchievementUnlockView(achievement: achievement)
                .presentationDetents([.medium])
        }
        .toast($model.toast)
    }

    /// Re-selecting a tab runs its "go to now" action.
    private var tabSelection: Binding<AppTab> {
        Binding(get: { model.selectedTab }, set: { tab in
            if tab == model.selectedTab { model.reselect(tab) }
            model.selectedTab = tab
        })
    }

    private var unlockBinding: Binding<Achievement?> {
        Binding(get: { model.unlockQueue.first }, set: { value in
            if value == nil, !model.unlockQueue.isEmpty { model.unlockQueue.removeFirst() }
        })
    }

    @ViewBuilder
    private func screen(_ content: some View) -> some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(Theme.teal)
                        Text(model.t("locating")).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.loadError {
                    ContentUnavailableView {
                        Label(error, systemImage: "exclamationmark.circle")
                    } actions: {
                        Button(model.t("retry")) { model.reload() }.primaryActionStyle()
                    }
                } else {
                    content
                }
            }
            .background(AppBackground())
            .navigationTitle(model.t("app_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(model.t("search"))
                    .accessibilityIdentifier("open_global_search")
                }
            }
        }
    }
}

/// iOS 26 shrinks the glass tab bar while scrolling.
private struct TabBarMinimize: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
