import Flutter
import UIKit
import flutter_local_notifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var initialDeepLinkUri: String?
  private var widgetChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Capture launch URL if opened via widget deep link
    if let launchUrl = launchOptions?[.url] as? URL {
      initialDeepLinkUri = launchUrl.absoluteString
    }

    // Ensure notifications show even when app is open
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // Module 13: Wire up com.ekadashi.widget MethodChannel to App Group Shared Storage & Deep Links
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      let channel = FlutterMethodChannel(name: "com.ekadashi.widget", binaryMessenger: messenger)
      widgetChannel = channel

      channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        guard let self = self else { return }
        let appGroupId = "group.com.applausestudios.ekadashicalendar"
        let storageKey = "ekadashi_widget_payload_v2"
        let lastSaveTimeKey = "ekadashi_widget_last_save_time"

        switch call.method {
        case "getInitialDeepLink":
          let link = self.initialDeepLinkUri
          self.initialDeepLinkUri = nil // Consume once
          result(link)

        case "updateWidgetData":
          guard let args = call.arguments as? [String: Any],
                let payloadJson = args["payloadJson"] as? String,
                let data = payloadJson.data(using: .utf8) else {
            result(FlutterError(code: "INVALID_ARGS", message: "payloadJson required", details: nil))
            return
          }

          if let userDefaults = UserDefaults(suiteName: appGroupId) {
            userDefaults.set(data, forKey: storageKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: lastSaveTimeKey)
            userDefaults.synchronize()

            WidgetRefreshManager.shared.reloadEkadashiWidgets()
            result(true)
          } else {
            result(FlutterError(code: "STORAGE_ERROR", message: "Failed to access App Group UserDefaults", details: nil))
          }

        case "forceWidgetRefresh":
          WidgetRefreshManager.shared.reloadAllWidgets()
          result(true)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle widget deep link when app is already running or in background
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let uriString = url.absoluteString
    if let channel = widgetChannel {
      channel.invokeMethod("onDeepLink", arguments: uriString)
    } else {
      initialDeepLinkUri = uriString
    }
    return true
  }
}
