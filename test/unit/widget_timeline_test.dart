import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:ekadashi_calendar/services/widget_sync_manager.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    await initializeDateFormatting();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  EkadashiDate event(int year, int serial, DateTime start) => EkadashiDate(
    id: year * 1000 + serial,
    occurrenceUid: 'ekadashi:$year:$serial',
    name: 'Year $year',
    date: DateTime(year, start.month, start.day),
    fastStartTime: '',
    fastBreakTime: '',
    description: '',
    fastingStartIso: start.toIso8601String(),
    paranaStartIso: start.add(const Duration(days: 1)).toIso8601String(),
    paranaEndIso: start
        .add(const Duration(days: 1, hours: 2))
        .toIso8601String(),
  );
  Future<Map<String, dynamic>> payload(
    List<EkadashiDate> events,
    DateTime now, {
    String language = 'en',
    String zone = 'IST',
  }) async {
    final lang = LanguageService();
    await lang.changeLanguage(language);
    return WidgetSyncManager().buildPayload(
      ekadashiList: events,
      timezone: zone,
      locationName: 'Test',
      languageService: lang,
      now: now,
    );
  }

  test(
    'unsorted multi-year archive skips all expired rows and selects 2027',
    () async {
      final a = event(2026, 1, DateTime.utc(2026, 12, 1)),
          b = event(2026, 2, DateTime.utc(2026, 12, 15)),
          c = event(2027, 1, DateTime.utc(2027, 1, 5));
      final p = await payload([c, a, b], DateTime.utc(2027, 1, 1));
      expect(p['nextEkadashi']['year'], 2027);
      expect(p['upcomingEkadashis'], isEmpty);
    },
  );
  test(
    'exhausted calendar clears widget data instead of showing first archived event',
    () async {
      final p = await payload([
        event(2027, 1, DateTime.utc(2027, 1, 5)),
      ], DateTime.utc(2028));
      expect(p['nextEkadashi'], isNull);
      expect(p['currentState'], 'FALLBACK');
    },
  );
  test(
    'fasting/parana countdown targets change at exact transitions',
    () async {
      final start = DateTime.utc(2027, 1, 5), e = event(2027, 1, start);
      for (final tuple in [
        (
          start.subtract(const Duration(seconds: 1)),
          'BEFORE_EKADASHI',
          e.fastingStartIso,
        ),
        (start, 'FASTING_ACTIVE', e.paranaStartIso),
        (
          start.add(const Duration(days: 1)),
          'PARANA_AVAILABLE',
          e.paranaEndIso,
        ),
      ]) {
        final p = await payload([e], tuple.$1);
        expect(p['currentState'], tuple.$2);
        expect(p['nextEkadashi']['countdownTarget'], tuple.$3);
      }
    },
  );
  test('today uses selected location across midnight', () async {
    final e = event(2027, 1, DateTime.utc(2027, 1, 5));
    final p = await payload([e], DateTime.utc(2027, 1, 4, 20), zone: 'IST');
    expect(p['today']['isEkadashi'], isTrue);
    final west = await payload([e], DateTime.utc(2027, 1, 4, 20), zone: 'PST');
    expect(west['today']['isEkadashi'], isFalse);
  });
  for (final language in ['en', 'ta', 'hi', 'te']) {
    test(
      '$language provides every widget label without leaking raw keys',
      () async {
        final p = await payload(
          [event(2027, 1, DateTime.utc(2027, 1, 5))],
          DateTime.utc(2027),
          language: language,
        );
        final strings = p['localizedStrings'] as Map;
        expect(strings, hasLength(23));
        for (final value in strings.values) {
          expect(value, isNotEmpty);
          expect(value, isNot(startsWith('widget_')));
        }
        if (language != 'en') {
          expect(strings['widget.next_ekadashi'], isNot('Next Ekadashi'));
        }
      },
    );
  }
}
