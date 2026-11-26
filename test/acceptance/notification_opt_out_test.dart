// Reproduce on the main-based local test branch. This test is intentionally red
// until the master reminder preference is enforced across all scheduling paths.
import 'package:ekadashi_calendar/widgets/app_icons.dart';
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
      await tester.tap(find.byIcon(AppIcons.tabSettings));
      await tester.pumpAndSettle();
      // Settings > Notifications has its own page (25 Nov 2026).
      await tester.ensureVisible(
        find.byKey(const Key('settings_notifications')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_notifications')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Enable Notifications'),
      );
      await tester.pumpAndSettle();
      expect(harness.notificationsEnabled, isFalse);
      harness.notificationCalls.clear();
      await tester.tap(find.byIcon(AppIcons.tabHome));
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
