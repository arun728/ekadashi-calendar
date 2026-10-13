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
  String? homeCity(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('home_location_name'))).data;

  testWidgets(
    'GPS unavailable keeps Chennai, not the device time zone, and retains navigation',
    (tester) async {
      harness.gpsAvailable = false;
      harness.deviceTimezone = 'America/New_York';
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text('Location Denied'), findsNothing);
      expect(homeCity(tester), 'Chennai (IN)');
      final request = harness.notificationCalls.lastWhere(
        (call) => call.method == 'scheduleAllNotifications',
      );
      final events = (request.arguments as Map)['ekadashis'] as List;
      expect((events.first as Map)['fastingStart'], endsWith('+05:30'));
      await tester.tap(find.byIcon(Icons.calendar_month));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Denied notifications disable reminder controls without losing Settings',
    (tester) async {
      harness.notificationGranted = false;
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      // Notifications sits below the Premium card and the Appearance section.
      await tester.ensureVisible(
        find.text('Notifications disabled', skipOffstage: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications disabled'), findsOneWidget);
      // The Ekadashi switches are a sub-section below the master switch.
      await tester.scrollUntilVisible(
        find.widgetWithText(SwitchListTile, '2 Days Before'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      final reminder = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '2 Days Before'),
      );
      expect(reminder.value, isFalse);
      expect(reminder.onChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Master reminder disable persists and sends native cancellation',
    (tester) async {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      // Notifications sits below the Premium card and the Appearance section.
      await tester.ensureVisible(
        find.widgetWithText(
          SwitchListTile,
          'Enable Notifications',
          skipOffstage: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Enable Notifications'),
      );
      await tester.pumpAndSettle();
      expect(harness.notificationsEnabled, isFalse);
      expect(
        harness.notificationCalls.where(
          (call) => call.method == 'cancelAllNotifications',
        ),
        isNotEmpty,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, '2 Days Before'),
            )
            .onChanged,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('App loads Home with resolved city and schedules ISO timings', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    // The detected city and its country, without a time zone.
    expect(homeCity(tester), 'Chennai (IN)');
    expect(find.byIcon(Icons.home), findsOneWidget);
    final request = harness.notificationCalls.lastWhere(
      (c) => c.method == 'scheduleAllNotifications',
    );
    final events = (request.arguments as Map)['ekadashis'] as List;
    // Every enabled year from the Panchang engine at Chennai (Smarta).
    expect(events, hasLength(49));
    expect(events.cast<Map>().map((e) => e['calendarYear']).toSet(), {
      2026,
      2027,
    });
    for (final event in events.cast<Map>()) {
      expect(DateTime.tryParse(event['fastingStart'] as String), isNotNull);
      expect(DateTime.tryParse(event['paranaStart'] as String), isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Location denial still leaves calendar and settings usable', (
    tester,
  ) async {
    harness.locationGranted = false;
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    // Without a location Home calculates for Chennai; the city picker
    // offers the search and "Use current location".
    expect(homeCity(tester), 'Chennai (IN)');
    expect(find.text('Location Denied'), findsNothing);
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bottom navigation preserves Home after Calendar and Settings', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(
      find.text('Enable Notifications', skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    expect(homeCity(tester), 'Chennai (IN)');
    expect(tester.takeException(), isNull);
  });
}
