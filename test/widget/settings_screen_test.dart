import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/screens/settings_screen.dart';
import 'package:ekadashi_calendar/screens/widget_preview_screen.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_launched': true,
      'app_version': '1.0',
    });

    const settingsChannel = MethodChannel('com.ekadashi.settings');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'checkAllPermissions') {
        return {
          'hasNotificationPermission': true,
          'hasLocationPermission': true,
          'hasExactAlarmPermission': true,
        };
      }
      if (methodCall.method == 'getAllSettings') {
        return {
          'permissions': {
            'hasNotificationPermission': true,
            'hasLocationPermission': true,
            'hasExactAlarmPermission': true,
          },
          'notifications': {
            'enabled': true,
            'remind2Days': true,
            'remind1Day': true,
            'remindOnStart': true,
            'remindOnParana': true,
          },
          'location': {
            'autoDetect': true,
            'timezone': 'IST',
          },
          'theme': {'isDarkMode': false},
        };
      }
      return null;
    });

    const notificationChannel = MethodChannel('com.ekadashi.notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (MethodCall methodCall) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.ekadashi.settings'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.ekadashi.notifications'), null);
  });

  testWidgets('SettingsScreen does NOT contain Widget Preview Cards or Widgets section', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify standard settings items ARE present
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);

    // 2. Verify Widget Preview Cards & Widgets section are NOT present
    expect(find.text('Widget Preview'), findsNothing);
    expect(find.text('Widget Preview Cards'), findsNothing);
    expect(find.text('Preview Home Screen Widgets'), findsNothing);
    expect(find.text('Widgets'), findsNothing);
    expect(find.byIcon(Icons.widgets_outlined), findsNothing);

    // 3. Verify no navigation to WidgetPreviewScreen is possible from Settings
    expect(find.byType(WidgetPreviewScreen), findsNothing);
  });
}
