import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URL (the test hook for [InAppBrowser.opener]).
typedef UrlOpener =
    Future<bool> Function(
      Uri uri, {
      LaunchMode mode,
      BrowserConfiguration browserConfiguration,
    });

/// Web pages such as Terms and Privacy open inside the app in Chrome Custom
/// Tabs with the page title, as X opens links, instead of the Chrome app
/// (report issue 9, 26 Nov 2026). If no in-app browser can open, the
/// browser app opens the page.
class InAppBrowser {
  static UrlOpener opener = _launch;

  static Future<bool> _launch(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
    BrowserConfiguration browserConfiguration = const BrowserConfiguration(),
  }) => launchUrl(uri, mode: mode, browserConfiguration: browserConfiguration);

  @visibleForTesting
  static void reset() => opener = _launch;

  static Future<void> open(Uri uri) async {
    try {
      if (await opener(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      )) {
        return;
      }
    } catch (e) {
      debugPrint('In-app browser unavailable: $e');
    }
    try {
      await opener(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Browser unavailable: $e');
    }
  }
}
