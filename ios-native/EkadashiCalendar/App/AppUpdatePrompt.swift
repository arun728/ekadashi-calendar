import SwiftUI
import StoreKit
import EkadashiCore

struct AppUpdatePrompt: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var isPresented = false
    @State private var offeredVersions: Set<String> = []
    @State private var lastCheck: Date?

    private var appID: String {
        Bundle.main.object(forInfoDictionaryKey: "EkadashiAppStoreId") as? String ?? ""
    }

    private var canCheck: Bool {
        scenePhase == .active && !model.isLoading && !model.showSearch && model.paywall == nil
            && model.googlePicker == nil && model.unlockQueue.isEmpty
    }

    func body(content: Content) -> some View {
        content
            .task(id: canCheck) {
                if canCheck { await check() }
            }
            .alert(model.t("ios_update_available"), isPresented: $isPresented) {
                Button(model.t("ios_update_now")) {
                    if let url = URL(string: AppLinks.appStore(id: appID)) { openURL(url) }
                }
                Button(model.t("ios_update_later"), role: .cancel) {}
            } message: {
                Text(model.t("ios_update_message"))
            }
    }

    private func check() async {
        let now = Date()
        if let lastCheck, now.timeIntervalSince(lastCheck) < 6 * 60 * 60 { return }
        let latest = await availableVersion()
        guard !Task.isCancelled else { return }
        lastCheck = now
        guard let latest, offeredVersions.insert(latest).inserted else { return }
        isPresented = true
    }

    private func availableVersion() async -> String? {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return nil }
        let data: Data
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            guard let version = ProcessInfo.processInfo.environment["EKADASHI_UI_TEST_STORE_VERSION"],
                  let id = Int(appID) else { return nil }
            let fixture = ["results": [["version": version, "minimumOsVersion": "17.0", "bundleId": bundleID, "trackId": id] as [String: Any]]]
            guard let testData = try? JSONSerialization.data(withJSONObject: fixture) else { return nil }
            data = testData
        } else {
            guard !DisplayClock.isSimulationSession, let response = await fetchListing() else { return nil }
            data = response
        }
        #else
        guard let response = await fetchListing() else { return nil }
        data = response
        #endif
        return AppStoreUpdate.availableVersion(in: data, appID: appID, bundleID: bundleID,
            installedVersion: installed, systemVersion: UIDevice.current.systemVersion)
    }

    private func fetchListing() async -> Data? {
        guard let storefront = await Storefront.current,
              let url = AppStoreUpdate.lookupURL(appID: appID, storefrontCode: storefront.countryCode),
              let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 10)),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }
}
