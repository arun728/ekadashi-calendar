import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/screens/settings_screen.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_launched': true,
      'app_version': '1.0',
    });
  });

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

  Widget buildTestableApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: const MaterialApp(
        home: MainScreen(),
      ),
    );
  }

  testWidgets('Bottom navigation contains exactly 4 items in correct order: Home, Calendar, Search, Settings', (tester) async {
    mockChannels(locationDenied: false);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestableApp());
    await tester.pumpAndSettle();

    // 1. Locate BottomNavigationBar
    final navBarFinder = find.byType(BottomNavigationBar);
    expect(navBarFinder, findsOneWidget);

    final BottomNavigationBar navBar = tester.widget(navBarFinder);

    // 2. Exactly 4 items
    expect(navBar.items.length, 4);

    // 3. Verify Exact Order:
    // Item 0: Home
    expect(navBar.items[0].label, 'Home');
    // Item 1: Calendar
    expect(navBar.items[1].label, 'Calendar');
    // Item 2: Search (Immediately right of Calendar!)
    expect(navBar.items[2].label, 'Search');
    // Item 3: Settings
    expect(navBar.items[3].label, 'Settings');

    // Confirm NO Vrat item exists
    expect(find.text('Vrat'), findsNothing);

    // 4. Verify no Search icon button remains in top AppBar on Home tab
    final topAppBarFinder = find.byType(AppBar);
    if (topAppBarFinder.evaluate().isNotEmpty) {
      final appBarActions = find.descendant(
        of: topAppBarFinder,
        matching: find.byType(IconButton),
      );
      for (final element in appBarActions.evaluate()) {
        final iconButton = element.widget as IconButton;
        final icon = iconButton.icon;
        if (icon is Icon) {
          expect(icon.icon, isNot(Icons.search), reason: 'Search icon must NOT be in the top AppBar!');
        }
      }
    }

    // 5. Test Navigation Flow:
    // Initial State is Home (index 0)
    expect(navBar.currentIndex, 0);

    // Tap Search (Item 2)
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Verify Search tab is active and GlobalSearchScreen is displayed
    final navBarAfterSearch = tester.widget<BottomNavigationBar>(navBarFinder);
    expect(navBarAfterSearch.currentIndex, 2);
    expect(find.byType(GlobalSearchScreen), findsOneWidget);

    // Tap Settings (Item 3)
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final navBarAfterSettings = tester.widget<BottomNavigationBar>(navBarFinder);
    expect(navBarAfterSettings.currentIndex, 3);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Tap Search again (Item 2)
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    final navBarAfterSearchAgain = tester.widget<BottomNavigationBar>(navBarFinder);
    expect(navBarAfterSearchAgain.currentIndex, 2);
    expect(find.byType(GlobalSearchScreen), findsOneWidget);

    // Tap Home (Item 0)
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    final navBarAfterHome = tester.widget<BottomNavigationBar>(navBarFinder);
    expect(navBarAfterHome.currentIndex, 0);
  });
}
