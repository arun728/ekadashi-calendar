import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/time_zone_data.dart';

/// The bundled IANA 2026b data covers 1900-2100: recurring summer time after
/// 2037 and the offsets before each zone's first transition
/// (TimeZoneCoverageTests.swift; fixture from Python ZoneInfo on official
/// compiled TZif files).
void main() {
  setUpAll(initializeTimeZoneData);

  int offset(String zone, DateTime utc) => PanchangCity(
    id: zone,
    label: zone,
    latitude: 0,
    longitude: 0,
    timeZoneId: zone,
  ).wallClock(utc).timeZoneOffset.inSeconds;

  test('recurring summer time continues after 2037', () {
    for (final year in [2038, 2050, 2100, 2101]) {
      for (final (zone, expected) in [
        ('Europe/London', 3600),
        ('Europe/Oslo', 7200),
        ('America/New_York', -14400),
        ('Australia/Sydney', 36000),
      ]) {
        expect(
          offset(zone, DateTime.utc(year, 7, 15, 12)),
          expected,
          reason: '$zone $year',
        );
      }
    }
  });

  test('historical offset before the first transition is preserved', () {
    for (final (zone, expected) in [
      ('Africa/Luanda', 815),
      ('America/Detroit', -19931),
    ]) {
      expect(
        offset(zone, DateTime.utc(1900, 6, 21, 12)),
        expected,
        reason: zone,
      );
    }
  });

  test('every IANA zone across 1900-2100 matches the independent TZif', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/time_zones/iana_2026b_1900_2100.json',
              ).readAsStringSync(),
            )
            as Map;
    final dates = [
      for (final text in fixture['utc'] as List) DateTime.parse(text as String),
    ];
    var failures = 0;
    final examples = <String>[];
    (fixture['offsetSecondsByZone'] as Map).forEach((zone, offsets) {
      // The database itself, as TimeZoneCoverageTests reads it: the fixture
      // also lists zones such as EST and CET that cities never use.
      final location = tz.getLocation(zone as String);
      final list = (offsets as List).cast<int>();
      for (var i = 0; i < dates.length; i++) {
        final actual =
            location.timeZone(dates[i].millisecondsSinceEpoch).offset ~/ 1000;
        if (actual != list[i]) {
          failures++;
          if (examples.length < 12) {
            examples.add('$zone ${dates[i]}: $actual, expected ${list[i]}');
          }
        }
      }
    });
    expect(failures, 0, reason: examples.join('\n'));
  });

  test('polar fallback samples the correct local 6 AM in 2100', () {
    const tromso = PanchangCity(
      id: 'tromso',
      label: 'Tromso',
      latitude: 69.6492,
      longitude: 18.9553,
      timeZoneId: 'Europe/Oslo',
    );
    final day = const PanchangEngine().calculate(
      DateTime.utc(2100, 6, 21),
      city: tromso,
    );
    expect(day.sunriseUtc, isNull);
    // Local 06:00 is 04:00 UTC under the IANA summer-time rule. Swiss
    // Ephemeris ends tithi 14 at 04:00:17 UTC; the Drik time base moves that
    // end one Delta T (about 93 s in 2100) earlier, to 03:58:44, so the 04:00
    // sample is tithi 15, karana 29. (The offsets themselves are checked by
    // the tests above.)
    expect(day.tithi.index, 15);
    expect(day.karana.index, 29);
  });

  test('schedules recalculate caches made with older rules', () {
    const key = EkadashiScheduleKey(
      PanchangCity.london,
      EkadashiTradition.smarta,
      2100,
    );
    expect(key.cacheId, startsWith('schedule-4|'));
  });
}
