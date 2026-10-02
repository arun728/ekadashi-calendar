import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';

Widget createTestApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeService()),
      ChangeNotifierProvider(create: (_) => LanguageService()),
    ],
    child: const MyApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_launched': true,
      'app_version': '1.0',
    });
  });

  // Mock Native Channels
  void mockChannels({bool locationDenied = false}) {
    // Settings Channel
    const settingsChannel = MethodChannel('com.ekadashi.settings');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'checkAllPermissions') {
        return {
          'hasNotificationPermission': true,
          'hasLocationPermission': !locationDenied,
          'hasExactAlarmPermission': true,
        };
      }
      if (methodCall.method == 'hasLocationPermission') return !locationDenied;
      if (methodCall.method == 'getLocationSettings') {
        return {'autoDetect': true, 'timezone': 'IST'};
      }
      return null;
    });

    // Location Channel
    const locationChannel = MethodChannel('com.ekadashi.location');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(locationChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'hasLocationPermission') return !locationDenied;
      if (methodCall.method == 'requestLocationPermission') return !locationDenied;
      if (methodCall.method == 'shouldShowRequestRationale') return true;
      if (methodCall.method == 'getCurrentLocation') {
        if (locationDenied) return null;
        return {
          'success': true,
          'city': 'Chennai',
          'timezone': 'IST',
          'latitude': 13.0,
          'longitude': 80.0,
        };
      }
      if (methodCall.method == 'getCachedLocation') {
        return {
          'success': true,
          'city': 'Chennai',
          'timezone': 'IST',
        };
      }
      return null;
    });

    // Notification Channel
    const notifChannel = MethodChannel('com.ekadashi.notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getSettings') {
        return {'notifications_enabled': true};
      }
      return null;
    });

    // Timezone Channel
    const timezoneChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, (MethodCall methodCall) async {
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
      if (key == 'assets/ekadashi_data.json') {
         const json = '''
      {
        "ekadashis": [
          {
            "id": 1,
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

  testWidgets('App loads and shows Home screen with Location', (WidgetTester tester) async {
    mockChannels(locationDenied: false);

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Verify Home Screen
    expect(find.text('Ekadashi Calendar'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    
    // Verify Location Text (Chennai comes from mock)
    expect(find.textContaining('Chennai'), findsOneWidget);
  });

  testWidgets('App handles Location Denied state', (WidgetTester tester) async {
    mockChannels(locationDenied: true);

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Verify "Location Denied" text
    expect(find.text('Location Denied'), findsOneWidget);
  });

  testWidgets('Navigation to Calendar and Settings', (WidgetTester tester) async {
    mockChannels(locationDenied: false);

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Tap Calendar
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    
    // Tap Settings
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Verify Settings Screen content
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
  });
}

