import 'package:package_info_plus/package_info_plus.dart';

/// The version of the installed build ("2.0.0" for pubspec 2.0.0+5), as
/// iOS shows CFBundleShortVersionString. Empty where the platform plugin is
/// missing (tests), never an error.
Future<String> appVersion() async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    return '';
  }
}
