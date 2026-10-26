import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

/// The normal clock is unchanged. The override branch is compiled out of
/// profile/release; only a separate integration-test entrypoint installs it.
class DisplayClock {
  static DateTime Function()? _testClock;
  static bool get isTesting => kDebugMode && _testClock != null;
  static DateTime now() {
    if (kDebugMode && _testClock != null) return _testClock!();
    return clock.now();
  }

  static void setTestClock(DateTime Function()? value) {
    if (kDebugMode) {
      assert(() {
        debugPrint('EKADASHI_ANDROID_TEST_CLOCK');
        return true;
      }());
      _testClock = value;
    }
  }
}
