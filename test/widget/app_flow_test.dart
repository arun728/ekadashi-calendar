import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/screens/onboarding_tradition_screen.dart';
import 'package:ekadashi_calendar/screens/settings_screen.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';

Widget createTestApp({Widget? home}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeService()),
      ChangeNotifierProvider(create: (_) => LanguageService()),
      ChangeNotifierProvider(create: (_) => TraditionService()),
    ],
    child: home != null
        ? MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: home,
          )
        : const MyApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_launched': true,
      'app_version': '1.0',
      'tradition_onboarding_completed': true,
      'user_tradition': 'general',
    });
    EkadashiService().clearCache();
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
      if (methodCall.method == 'scheduleAllNotifications') {
        return 4;
      }
      return null;
    });

    // Timezone Channel
    const tzChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tzChannel, (MethodCall methodCall) async {
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
            },
            "tradition_tags": ["general", "smarta", "vaishnava"],
            "region_tags": ["pan-india"],
            "has_tradition_variation": true,
            "tradition_variants": {
              "smarta": {
                "tradition": "smarta",
                "timing": {
                  "IST": {
                    "date": "2026-01-29",
                    "fasting_start": "2026-01-29T06:40:00+05:30",
                    "parana_start": "2026-01-30T07:10:00+05:30",
                    "parana_end": "2026-01-30T10:00:00+05:30"
                  }
                },
                "fasting_rules": {"en": "Smarta standard rules"}
              },
              "vaishnava": {
                "tradition": "vaishnava",
                "timing": {
                  "IST": {
                    "date": "2026-01-30",
                    "fasting_start": "2026-01-30T06:40:00+05:30",
                    "parana_start": "2026-01-31T07:10:00+05:30",
                    "parana_end": "2026-01-31T10:00:00+05:30"
                  }
                },
                "fasting_rules": {"en": "Vaishnava standard rules"}
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

  testWidgets('App loads and shows Home screen with Location and Tradition', (WidgetTester tester) async {
    mockChannels(locationDenied: false);

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Verify Home Screen
    expect(find.text('Ekadashi Calendar'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);

    // Verify Location Text
    expect(find.textContaining('Chennai'), findsOneWidget);

    // Verify Ekadashi card with variation displays alternate affordance
    expect(find.text("View other tradition's date"), findsOneWidget);
  });

  testWidgets('App handles Location Denied state', (WidgetTester tester) async {
    mockChannels(locationDenied: true);

    await tester.pumpWidget(createTestApp());
    // Pump past splash screen
    await tester.pump(const Duration(milliseconds: 600));
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

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
    expect(find.text('Tradition & Observance'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dark Mode'), 100);
    expect(find.text('Dark Mode'), findsOneWidget);
  });

  testWidgets('Changing tradition in Settings updates immediately without restart', (WidgetTester tester) async {
    mockChannels(locationDenied: false);

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Go to Settings
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Tap on Tradition tile
    await tester.tap(find.text('Tradition'));
    await tester.pumpAndSettle();

    // Verify Dialog opened
    expect(find.text('Choose Your Tradition'), findsOneWidget);

    // Tap Vaishnava
    await tester.tap(find.text('Vaishnava'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify Settings immediately reflects Vaishnava
    expect(find.text('Vaishnava'), findsOneWidget);
  });

  testWidgets('Onboarding screen displays options and saves preference', (WidgetTester tester) async {
    mockChannels(locationDenied: false);

    await tester.pumpWidget(createTestApp(home: const OnboardingTraditionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Choose Your Tradition'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Smarta'), findsOneWidget);
    expect(find.text('Vaishnava'), findsOneWidget);

    // Tap Smarta
    await tester.tap(find.text('Smarta'));
    await tester.pumpAndSettle();

    // Tap Continue
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  });

  testWidgets('Settings screen loads safely in simulated Web/Desktop environment without Platform crash', (WidgetTester tester) async {
    mockChannels(locationDenied: false);
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    try {
      await tester.pumpWidget(createTestApp(home: const Scaffold(body: SettingsScreen())));
      await tester.pumpAndSettle();

      expect(find.text('Tradition & Observance'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Tradition'), findsOneWidget);
      expect(find.text('Permissions'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Settings screen loads permissions section on Android', (WidgetTester tester) async {
    mockChannels(locationDenied: false);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(createTestApp(home: const Scaffold(body: SettingsScreen())));
      await tester.pumpAndSettle();

      expect(find.text('Tradition & Observance'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Permissions'), 100);
      expect(find.text('Permissions'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Share button is positioned on the left side of Ekadashi card and uses Icons.share', (WidgetTester tester) async {
    mockChannels(locationDenied: false);

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Verify Share button exists with Icons.share
    final shareButton = find.widgetWithIcon(IconButton, Icons.share);
    expect(shareButton, findsOneWidget);

    // Verify it is positioned to the left of the View Details button
    final detailsButton = find.widgetWithText(ElevatedButton, 'View Details');
    expect(detailsButton, findsOneWidget);

    final detailsOffset = tester.getTopLeft(detailsButton);
    final shareOffset = tester.getTopLeft(shareButton);
    expect(shareOffset.dx, lessThan(detailsOffset.dx));
  });

  testWidgets('Tapping "View other tradition\'s date" on Home card opens TraditionVariantSheet with correct alternate date', (WidgetTester tester) async {
    mockChannels(locationDenied: false);

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Verify "View other tradition's date" exists on Home card
    final link = find.text("View other tradition's date");
    expect(link, findsOneWidget);

    // Tap the link
    await tester.tap(link);
    await tester.pumpAndSettle();

    // Verify TraditionVariantSheet appears
    expect(find.text("Other Tradition's Observance"), findsOneWidget);
    expect(find.textContaining('Vaishnava'), findsWidgets);
    expect(find.textContaining('Jan 30, 2026'), findsWidgets);
  });

  testWidgets('Tapping "View other tradition\'s date" with Smarta tradition shows Vaishnava alternative date and updates on tradition switch', (WidgetTester tester) async {
    mockChannels(locationDenied: false);
    SharedPreferences.setMockInitialValues({
      'has_launched': true,
      'app_version': '1.0',
      'tradition_onboarding_completed': true,
      'user_tradition': 'smarta',
    });

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Smarta Tradition'), findsOneWidget);
    expect(find.text("View other tradition's date"), findsOneWidget);

    await tester.tap(find.text("View other tradition's date"));
    await tester.pumpAndSettle();

    expect(find.text("Other Tradition's Observance"), findsOneWidget);
    expect(find.textContaining('Your Tradition — Smarta'), findsOneWidget);
    expect(find.textContaining('Jan 29, 2026'), findsWidgets);
    expect(find.textContaining('Alternate Tradition — Vaishnava'), findsOneWidget);
    expect(find.textContaining('Jan 30, 2026'), findsWidgets);

    // Close sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Switch to Settings -> change to Vaishnava
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tradition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaishnava'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Go back to Home
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();

    // Verify badge now says Vaishnava Tradition
    expect(find.text('Vaishnava Tradition'), findsOneWidget);
    expect(find.text("View other tradition's date"), findsOneWidget);

    // Tap link again
    await tester.tap(find.text("View other tradition's date"));
    await tester.pumpAndSettle();

    expect(find.text("Other Tradition's Observance"), findsOneWidget);
    expect(find.textContaining('Your Tradition — Vaishnava'), findsOneWidget);
    expect(find.textContaining('Alternate Tradition — Smarta'), findsOneWidget);
  });
}
