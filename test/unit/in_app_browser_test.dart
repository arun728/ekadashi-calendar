import 'package:ekadashi_calendar/services/in_app_browser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

/// Report issue 9 (Arun, 26 Nov 2026): web pages open in Chrome Custom Tabs
/// inside the app (as X does); if that fails, the browser app opens them.
void main() {
  tearDown(InAppBrowser.reset);
  final page = Uri.parse(
    'https://apptinel.com/ekadashi-calendar/privacy-policy/',
  );

  test('opens in the in-app browser with the page title', () async {
    final calls = <(LaunchMode, bool)>[];
    InAppBrowser.opener =
        (
          uri, {
          mode = LaunchMode.platformDefault,
          browserConfiguration = const BrowserConfiguration(),
        }) async {
          calls.add((mode, browserConfiguration.showTitle));
          return true;
        };
    await InAppBrowser.open(page);
    expect(calls, [(LaunchMode.inAppBrowserView, true)]);
  });

  test('falls back to the browser app when no in-app browser opens', () async {
    final modes = <LaunchMode>[];
    InAppBrowser.opener =
        (
          uri, {
          mode = LaunchMode.platformDefault,
          browserConfiguration = const BrowserConfiguration(),
        }) async {
          modes.add(mode);
          if (mode == LaunchMode.inAppBrowserView) {
            throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
          }
          return true;
        };
    await InAppBrowser.open(page);
    expect(modes, [
      LaunchMode.inAppBrowserView,
      LaunchMode.externalApplication,
    ]);
  });
}
