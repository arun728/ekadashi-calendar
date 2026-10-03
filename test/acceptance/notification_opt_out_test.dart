// Reproduce on the main-based local test branch. This test is intentionally red
// until the master reminder preference is enforced across all scheduling paths.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() => harness.uninstall());
  testWidgets(
    'Changing language cannot reschedule after reminders are disabled',
    (tester) async {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Enable Notifications'),
      );
      await tester.pumpAndSettle();
      expect(harness.notificationsEnabled, isFalse);
      harness.notificationCalls.clear();
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('தமிழ்').last);
      await tester.pumpAndSettle();
      expect(
        harness.notificationCalls.where(
          (call) => call.method == 'scheduleAllNotifications',
        ),
        isEmpty,
      );
    },
  );
}
