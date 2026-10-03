import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/native_widget_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NativeWidgetService widgetService;
  late LanguageService languageService;
  final List<MethodCall> log = <MethodCall>[];

  setUp(() async {
    await initializeDateFormatting('en', null);
    SharedPreferences.setMockInitialValues({});
    widgetService = NativeWidgetService();
    languageService = LanguageService();
    log.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ekadashi.widget'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'updateWidgetData') {
          return true;
        } else if (methodCall.method == 'forceWidgetRefresh') {
          return null;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.ekadashi.widget'),
      null,
    );
  });

  group('NativeWidgetService Tests', () {
    test('updateWidgetData returns false if ekadashiList is empty', () async {
      final success = await widgetService.updateWidgetData(
        ekadashiList: [],
        timezone: 'Asia/Kolkata',
        locationName: 'New Delhi',
        languageService: languageService,
      );

      expect(success, isFalse);
      expect(log.isEmpty, isTrue);
    });

    test('updateWidgetData builds canonical JSON payload correctly', () async {
      final now = DateTime.now().toUtc();
      final e1 = EkadashiDate(
        id: 1,
        name: 'Utpanna Ekadashi',
        date: DateTime.now().add(const Duration(days: 2)),
        fastStartTime: '06:00 AM',
        fastBreakTime: '06:30 AM - 10:00 AM',
        paksha: 'Krishna',
        month: 'Margashirsha',
        description: 'First Ekadashi of winter',
        fastingStartIso: now.add(const Duration(days: 1)).toIso8601String(),
        paranaStartIso: now.add(const Duration(days: 2, hours: 6)).toIso8601String(),
        paranaEndIso: now.add(const Duration(days: 2, hours: 10)).toIso8601String(),
      );
      final e2 = EkadashiDate(
        id: 2,
        name: 'Mokshada Ekadashi',
        date: DateTime.now().add(const Duration(days: 16)),
        fastStartTime: '06:00 AM',
        fastBreakTime: '06:30 AM - 10:00 AM',
        paksha: 'Shukla',
        month: 'Margashirsha',
        description: 'Gita Jayanti Ekadashi',
        fastingStartIso: now.add(const Duration(days: 15)).toIso8601String(),
        paranaStartIso: now.add(const Duration(days: 16, hours: 6)).toIso8601String(),
        paranaEndIso: now.add(const Duration(days: 16, hours: 10)).toIso8601String(),
      );

      final success = await widgetService.updateWidgetData(
        ekadashiList: [e1, e2],
        timezone: 'Asia/Kolkata',
        locationName: 'Vrindavan',
        languageService: languageService,
      );

      expect(success, isTrue);
      expect(log.length, 1);
      expect(log.first.method, 'updateWidgetData');

      final rawPayload = log.first.arguments['payloadJson'] as String;
      final Map<String, dynamic> payload = jsonDecode(rawPayload);

      // Verify metadata
      expect(payload['metadata']['schemaVersion'], 2);
      expect(payload['metadata']['dataVersion'], '2.0.0');
      expect(payload['metadata']['timezone'], 'Asia/Kolkata');
      expect(payload['metadata']['locationName'], 'Vrindavan');
      expect(payload['metadata']['locale'], 'en');

      // Verify current state is BEFORE_EKADASHI since fastingStart is in the future
      expect(payload['currentState'], 'BEFORE_EKADASHI');

      // Verify nextEkadashi
      expect(payload['nextEkadashi']['id'], 1);
      expect(payload['nextEkadashi']['name'], 'Utpanna Ekadashi');
      expect(payload['nextEkadashi']['paksha'], 'Krishna');

      // Verify upcomingEkadashis
      final upcoming = payload['upcomingEkadashis'] as List;
      expect(upcoming.length, 1);
      expect(upcoming.first['name'], 'Mokshada Ekadashi');

      // Verify localizedStrings bundle
      final localized = payload['localizedStrings'] as Map<String, dynamic>;
      expect(localized.containsKey('widget.next_ekadashi'), isTrue);
      expect(localized.containsKey('widget.fasting_active'), isTrue);
      expect(localized.containsKey('widget.parana_available'), isTrue);
    });

    test('forceWidgetRefresh invokes platform channel', () async {
      await widgetService.forceWidgetRefresh();
      expect(log.length, 1);
      expect(log.first.method, 'forceWidgetRefresh');
    });

    test('getInitialDeepLink retrieves and parses cold-start deep link', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.ekadashi.widget'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getInitialDeepLink') {
            return 'ekadashi://dashboard?action=parana';
          }
          return null;
        },
      );

      final uri = await widgetService.getInitialDeepLink();
      expect(uri, isNotNull);
      expect(uri?.scheme, 'ekadashi');
      expect(uri?.host, 'dashboard');
      expect(uri?.queryParameters['action'], 'parana');
    });

    test('initializeDeepLinkListener receives onDeepLink platform invocation', () async {
      Uri? receivedUri;
      widgetService.initializeDeepLinkListener((uri) {
        receivedUri = uri;
      });

      // Simulate native calling onDeepLink
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('com.ekadashi.widget');
      final message = channel.codec.encodeMethodCall(
        const MethodCall('onDeepLink', 'ekadashi://calendar?date=2026-10-15'),
      );

      await binding.handlePlatformMessage('com.ekadashi.widget', message, (data) {});

      expect(receivedUri, isNotNull);
      expect(receivedUri?.scheme, 'ekadashi');
      expect(receivedUri?.host, 'calendar');
      expect(receivedUri?.queryParameters['date'], '2026-10-15');
    });

    test('updateWidgetData includes tradition metadata when specified', () async {
      final now = DateTime.now().toUtc();
      final e1 = EkadashiDate(
        id: 1,
        name: 'Aja Ekadashi',
        date: DateTime.now().add(const Duration(days: 2)),
        fastStartTime: '06:00 AM',
        fastBreakTime: '06:30 AM - 10:00 AM',
        description: 'Observance',
        fastingStartIso: now.add(const Duration(days: 1)).toIso8601String(),
        paranaStartIso: now.add(const Duration(days: 2, hours: 6)).toIso8601String(),
        paranaEndIso: now.add(const Duration(days: 2, hours: 10)).toIso8601String(),
      );

      await widgetService.updateWidgetData(
        ekadashiList: [e1],
        timezone: 'Asia/Kolkata',
        locationName: 'Bengaluru',
        languageService: languageService,
        tradition: 'Vaishnava',
      );

      expect(log.isNotEmpty, isTrue);
      final rawPayload = log.last.arguments['payloadJson'] as String;
      final Map<String, dynamic> payload = jsonDecode(rawPayload);
      expect(payload['metadata']['tradition'], 'Vaishnava');
      expect(payload['metadata']['locationName'], 'Bengaluru');
    });
  });
}

