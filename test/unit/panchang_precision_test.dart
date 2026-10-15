import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/astronomy_calculator.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/time_zone_data.dart';
import 'package:ekadashi_calendar/services/widget_sync_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const engine = PanchangEngine();
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/panchang/precision_regressions.json',
            ).readAsStringSync(),
          )
          as Map;
  List<Map<String, dynamic>> pack(int year) =>
      (jsonDecode(
                File('assets/calendar/$year.json').readAsStringSync(),
              )['ekadashis']
              as List)
          .cast<Map<String, dynamic>>();
  List<ScheduledEkadashi> schedule(
    PanchangCity city,
    EkadashiTradition tradition,
    int year,
  ) => EkadashiSchedule.calculate(
    EkadashiScheduleKey(city, tradition, year),
    pack(year),
  );
  ScheduledEkadashi example(String start, String end, {String? expiry}) =>
      ScheduledEkadashi.fromJson({
        'occurrenceUid': 'review:1',
        'notificationId': 1,
        'legacyId': 1,
        'contentId': 'test',
        'publishedUid': null,
        'date': '2026-12-19',
        'fastingStart': '2026-12-19T07:15:00-05:00',
        'paranaStart': start,
        'paranaEnd': end,
        'paksha': 'krishna',
        'month': 'margashirsha',
        'rule': 'Test',
        'contextExpiresAt': expiry,
      });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Tuesday Ashlesha begins with Ananda', () {
    final day = engine.calculate(
      DateTime.utc(2026, 1, 6),
      city: PanchangCity.chennai,
    );
    expect(day.nakshatra.name, 'Ashlesha');
    expect(day.anandadiYoga, 'Ananda');
  });

  test(
    'Lagna uses a consistent apparent equinox and independent Swiss boundaries',
    () {
      for (final row in fixture['ascendants'] as List) {
        final time = DateTime.parse(row['utc']);
        final city = PanchangCity(
          id: 'fixture',
          label: 'Fixture',
          latitude: row['lat'],
          longitude: row['lon'],
          timeZoneId: 'UTC',
        );
        final angle = AstronomyCalculator.normalize(
          AstronomyCalculator.ascendantLongitude(
                time,
                city.latitude,
                city.longitude,
              ) -
              AstronomyCalculator.apparentLahiriAyanamsa(time),
        );
        expect(
          AstronomyCalculator.signedAngle(
                angle - row['siderealLongitude'],
              ).abs() *
              3600,
          lessThan(.2),
        );
        var day = engine.calculate(time, city: city);
        if (day.sunriseUtc!.isAfter(time)) {
          day = engine.calculate(
            time.subtract(const Duration(days: 1)),
            city: city,
          );
        }
        final period = day.lagna.firstWhere(
          (p) => !p.startUtc.isAfter(time) && p.endUtc.isAfter(time),
        );
        expect(
          period.endUtc
                  .difference(DateTime.parse(row['firstLagnaEndsUtc']))
                  .inMicroseconds
                  .abs() /
              1e6,
          lessThan(.2),
        );
      }
    },
  );

  test('Grazing rise and set are found between five-minute samples', () {
    final row = fixture['grazing'];
    final city = PanchangCity(
      id: 'grazing',
      label: 'Grazing horizon',
      latitude: row['lat'],
      longitude: row['lon'],
      timeZoneId: 'UTC',
    );
    final day = engine.calculate(DateTime.utc(2026, 12, 21), city: city);
    expect(day.sunriseUtc, isNotNull);
    expect(day.sunsetUtc, isNotNull);
    expect(
      day.sunriseUtc!
          .difference(DateTime.parse(row['sunriseUtc']))
          .inMilliseconds
          .abs(),
      lessThan(3000),
    );
    expect(
      day.sunsetUtc!
          .difference(DateTime.parse(row['sunsetUtc']))
          .inMilliseconds
          .abs(),
      lessThan(3000),
    );
    expect(day.sunsetUtc!.difference(day.sunriseUtc!).inSeconds, lessThan(100));
  });

  test('Stored schedule retains inward-rounded millisecond boundaries', () {
    final raw = const CalculatedEkadashiEngine()
        .calculate(
          DateTime.utc(2026),
          20,
          PanchangCity.chennai,
          EkadashiTradition.smarta,
        )
        .first;
    final stored = schedule(
      PanchangCity.chennai,
      EkadashiTradition.smarta,
      2026,
    ).first;
    final start = DateTime.parse(stored.paranaStart),
        end = DateTime.parse(stored.paranaEnd);
    expect(start.isBefore(raw.paranaStartUtc!), isFalse);
    expect(
      start.difference(raw.paranaStartUtc!).inMicroseconds,
      lessThan(2000),
    );
    expect(end.isAfter(raw.paranaEndUtc!), isFalse);
    expect(raw.paranaEndUtc!.difference(end).inMicroseconds, lessThan(2000));
  });

  test('After-only Parana has no invented end in Home', () {
    final stored = schedule(
      PanchangCity.newYork,
      EkadashiTradition.smarta,
      2026,
    ).firstWhere((f) => f.date == '2026-12-19');
    expect(stored.paranaEnd, isEmpty);
    final event = EkadashiService().fromScheduled(stored, {}, 'en');
    expect(event.paranaEndIso, isEmpty);
    expect(event.fastBreakTime, startsWith('after '));
  });

  test(
    'Narrow and subsecond windows are displayed inside the allowed interval',
    () {
      String display(String start, String end) => EkadashiService()
          .fromScheduled(example(start, end), {}, 'en')
          .fastBreakTime;
      expect(
        display(
          '2027-09-13T06:04:56.374+05:30',
          '2027-09-13T06:05:09.097+05:30',
        ),
        '06:04:57 AM - 06:05:09 AM',
      );
      expect(display('2026-12-20T15:05:32.063-05:00', ''), 'after 03:05:33 PM');
      expect(
        display('2027-01-01T23:59:59.200Z', '2027-01-02T00:00:01.900Z'),
        '12:00:00 AM - 12:00:01 AM',
      );
      expect(
        display('2027-01-01T06:00:00.100Z', '2027-01-01T06:00:00.900Z'),
        '06:00:00.100 AM - 06:00:00.900 AM',
      );
    },
  );

  test(
    'After-only widgets retain the event without fabricating a deadline',
    () async {
      await initializeDateFormatting();
      final stored = example(
        '2026-12-20T15:05:32.174-05:00',
        '',
        expiry: '2026-12-21T00:00:00-05:00',
      );
      final event = EkadashiService().fromScheduled(stored, {}, 'en');
      final payload = WidgetSyncManager().buildPayload(
        ekadashiList: [event],
        timezone: 'America/New_York',
        locationName: 'New York',
        languageService: LanguageService(),
        now: DateTime.parse('2026-12-20T15:06:00-05:00'),
      );
      expect(payload['currentState'], 'PARANA_AVAILABLE');
      expect(payload['nextEkadashi'], isNotNull);
      expect(payload['nextEkadashi']['paranaEndUTC'], isEmpty);
    },
  );

  test('Every schedule year uses the calculated Amanta month', () {
    final raw = const CalculatedEkadashiEngine()
        .calculate(
          DateTime.utc(2027),
          10,
          PanchangCity.newDelhi,
          EkadashiTradition.smarta,
        )
        .first;
    final stored = schedule(
      PanchangCity.newDelhi,
      EkadashiTradition.smarta,
      2027,
    ).first;
    expect(stored.month, EkadashiSchedule.monthKey(raw.month));
  });

  test('Cache separates exact positions and versions the timezone rules', () {
    const a = PanchangCity(
      id: 'gps',
      label: 'GPS',
      latitude: 13.082701,
      longitude: 80.270701,
    );
    const b = PanchangCity(
      id: 'gps',
      label: 'GPS',
      latitude: 13.082702,
      longitude: 80.270702,
    );
    const first = EkadashiScheduleKey(a, EkadashiTradition.smarta, 2026),
        second = EkadashiScheduleKey(b, EkadashiTradition.smarta, 2026);
    expect(first.cacheId, isNot(second.cacheId));
    expect(first.cacheId, contains(timeZoneDataRelease));
  });
}
