import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_launched': true,
      'app_version': '1.0',
      'vrat_tracker_enabled': false, // Legacy opt-out preference
    });
  });

  void mockChannels() {
    const settingsChannel = MethodChannel('com.ekadashi.settings');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'checkAllPermissions') {
            return {
              'hasNotificationPermission': true,
              'hasLocationPermission': true,
              'hasExactAlarmPermission': true,
            };
          }
          if (methodCall.method == 'hasLocationPermission') return true;
          if (methodCall.method == 'getLocationSettings') {
            return {'autoDetect': true, 'timezone': 'IST'};
          }
          return null;
        });

    const locationChannel = MethodChannel('com.ekadashi.location');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(locationChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'hasLocationPermission') return true;
          if (methodCall.method == 'getCurrentLocation') {
            return {
              'success': true,
              'city': 'Chennai',
              'timezone': 'IST',
              'latitude': 13.0,
              'longitude': 80.0,
            };
          }
          if (methodCall.method == 'getCachedLocation') {
            return {'success': true, 'city': 'Chennai', 'timezone': 'IST'};
          }
          return null;
        });

    const notifChannel = MethodChannel('com.ekadashi.notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'getSettings') {
            return {'notifications_enabled': true};
          }
          return null;
        });

    const timezoneChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'getLocalTimezone') {
            return 'Asia/Kolkata';
          }
          return null;
        });

    // Asset Channel (Mock rootBundle)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          if (message == null) return null;
          final String key = utf8.decode(message.buffer.asUint8List());
          if (key == 'assets/calendar/manifest.json') {
            return ByteData.sublistView(
              Uint8List.fromList(
                utf8.encode(
                  jsonEncode({
                    'schema_version': 1,
                    'packs': [
                      {'year': 2026, 'asset': 'assets/calendar/2026.json'},
                    ],
                  }),
                ),
              ),
            );
          }
          if (key == 'assets/calendar/2026.json') {
            const json = '''
      {
        "year": 2026, "schema_version": 1,
        "ekadashis": [
          {
            "id": 1, "legacy_id": 1, "notification_id": 1,
            "occurrence_uid": "ekadashi:2026:01", "content_id": "jaya-ekadashi",
            "paksha": "Shukla",
            "month": "Magha",
            "name": {"en": "Jaya Ekadashi"},
            "description": {"en": "Grants liberation."},
            "timing": {
              "IST": {
                "date": "2026-01-29",
                "fasting_start": "2026-01-29T06:40:00+05:30",
                "parana_start": "2026-01-30T07:10:00+05:30",
                "parana_end": "2026-01-30T10:00:00+05:30"
              }
            }
          }
        ]
      }
      ''';
            return ByteData.view(Uint8List.fromList(utf8.encode(json)).buffer);
          }
          return null;
        });
  }

  testWidgets('Free Vrat Tracker navigation and tab switching', (
    WidgetTester tester,
  ) async {
    mockChannels();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 1. Verify Home screen loaded
    expect(find.byIcon(Icons.spa_outlined), findsOneWidget);

    // 2. Navigate to Vrat Tracker tab
    await tester.tap(find.byIcon(Icons.spa_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Enable Vrat Tracker'), findsNothing);
    expect(find.text('Disable Vrat Tracker'), findsNothing);

    // 5. Verify Dashboard is displayed with metrics
    expect(find.text('Current Streak'), findsOneWidget);
    expect(find.text('Longest Streak'), findsOneWidget);
    expect(find.text('Total Observed'), findsOneWidget);
    expect(find.text('Next Milestone'), findsOneWidget);

    // 6. Switch to History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Jaya Ekadashi'), findsOneWidget);

    // 7. Switch to Statistics tab
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    expect(find.text('2026 Annual Completion'), findsOneWidget);

    // 8. Switch to Achievements tab
    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();
    expect(find.text('First Vrat'), findsOneWidget);
    expect(find.text('5 Ekadashis'), findsOneWidget);

    // Scroll to bottom of GridView to reveal remaining achievements
    await tester.scrollUntilVisible(
      find.text('Consistent Observance'),
      160,
      scrollable: find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Consistent Observance'), findsOneWidget);
    expect(find.text('Full-Year Observance'), findsOneWidget);
  });
}
