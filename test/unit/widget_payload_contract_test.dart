import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/widget_sync_manager.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Canonical upcoming payload must contain all nonoptional Swift Codable fields',
    () async {
      await initializeDateFormatting();
      Map<String, dynamic>? payload;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ekadashi.widget'),
            (c) async {
              payload = jsonDecode(
                (c.arguments as Map)['payloadJson'] as String,
              );
              return true;
            },
          );
      final now = DateTime.now().toUtc();
      final all = List.generate(3, (i) {
        final d = now.add(Duration(days: 10 + i * 15));
        return EkadashiDate(
          id: i + 1,
          name: 'Review ${i + 1}',
          date: d,
          fastStartTime: '06:00 AM',
          fastBreakTime: '06:00 AM - 08:00 AM',
          description: '',
          fastingStartIso: d.toIso8601String(),
          paranaStartIso: d.add(const Duration(days: 1)).toIso8601String(),
          paranaEndIso: d
              .add(const Duration(days: 1, hours: 2))
              .toIso8601String(),
        );
      });
      final ok = await WidgetSyncManager().syncWidgetData(
        ekadashiList: all,
        timezone: 'IST',
        locationName: 'Chennai',
        languageService: LanguageService(),
      );
      expect(ok, isTrue);
      final required = [
        'id',
        'name',
        'localizedName',
        'date',
        'localizedDate',
        'paksha',
        'month',
        'fastingStartUTC',
        'fastingEndUTC',
        'paranaStartUTC',
        'paranaEndUTC',
      ];
      for (final item in payload!['upcomingEkadashis'] as List) {
        final missing = required
            .where((k) => !(item as Map).containsKey(k))
            .toList();
        expect(missing, isEmpty);
      }
    },
  );
}
