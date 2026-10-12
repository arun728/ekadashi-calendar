import 'package:ekadashi_calendar/services/app_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Settings shows the version of the build (package_info_plus), never a
/// hard-coded number, and never crashes where the plugin is missing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without the plugin the version is empty, not an error', () async {
    expect(await appVersion(), '');
  });

  test('the build version (pubspec 2.0.0+5) is shown as 2.0.0', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Ekadashi Calendar',
      packageName: 'com.applausestudios.ekadashi_calendar',
      version: '2.0.0',
      buildNumber: '5',
      buildSignature: '',
    );
    expect(await appVersion(), '2.0.0');
  });
}
