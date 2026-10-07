import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/astronomy_calculator.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';

/// Accuracy gates from the independent harness (tool/panchang_accuracy and
/// docs/PANCHANG_ACCURACY.md): Swiss Ephemeris / JPL positions, published
/// Drik-sourced Ekadashi data and public Indian festival lists.
void main() {
  const engine = PanchangEngine();
  const chennai = PanchangCity(
    id: 'chennai',
    label: 'Chennai',
    latitude: 13.0827,
    longitude: 80.2707,
  );

  double arcseconds(double a, double b) =>
      AstronomyCalculator.signedAngle(a - b).abs() * 3600;

  test('Sun, Moon and Lahiri agree with Swiss Ephemeris to an arcsecond', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/panchang/swiss_ephemeris_positions.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final row in fixture['samples'] as List) {
      final instant = DateTime.parse(row['utc'] as String);
      expect(
        arcseconds(AstronomyCalculator.sunLongitude(instant), row['sun']),
        lessThan(0.5),
        reason: 'Sun $instant',
      );
      expect(
        arcseconds(AstronomyCalculator.moonLongitude(instant), row['moon']),
        lessThan(1.0),
        reason: 'Moon $instant',
      );
      expect(
        arcseconds(
          AstronomyCalculator.apparentLahiriAyanamsa(instant),
          row['lahiri'],
        ),
        lessThan(0.1),
        reason: 'Lahiri $instant',
      );
    }
  });

  test('Sun and Moon rise/set agree with Swiss Ephemeris within seconds', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/panchang/swiss_rise_set_2027.json',
              ).readAsStringSync(),
            )
            as Map;
    const zones = {
      'new-delhi': 'Asia/Kolkata',
      'london': 'Europe/London',
      'sydney': 'Australia/Sydney',
      'new-york': 'America/New_York',
    };
    for (final row in fixture['events'] as List) {
      final city = PanchangCity(
        id: row['city'],
        label: row['city'],
        latitude: row['lat'],
        longitude: row['lon'],
        timeZoneId: zones[row['city']]!,
      );
      final expected = DateTime.parse(row['utc'] as String);
      final local = city.wallClock(expected);
      final day = engine.calculate(
        DateTime.utc(local.year, local.month, local.day),
        city: city,
      );
      final actual = switch ('${row['body']} ${row['event']}') {
        'sun rise' => day.sunriseUtc,
        'sun set' => day.sunsetUtc,
        'moon rise' => day.moonriseUtc,
        _ => day.moonsetUtc,
      };
      expect(actual, isNotNull, reason: '$row');
      expect(
        actual!.difference(expected).inMilliseconds.abs() / 1000,
        lessThan(1),
        reason: '$row',
      );
    }
  });

  test(
    'polar, date-line, odd-offset and DST locations match Swiss Ephemeris',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/panchang/swiss_world_edges_2026.json',
                ).readAsStringSync(),
              )
              as Map;
      final failures = <String>[];
      for (final row in fixture['cases'] as List) {
        final city = PanchangCity(
          id: row['id'],
          label: row['id'],
          latitude: (row['lat'] as num).toDouble(),
          longitude: (row['lon'] as num).toDouble(),
          timeZoneId: row['tz'],
        );
        final date = DateTime.parse(row['date'] as String);
        final day = engine.calculate(date, city: city);
        void compare(String key, DateTime? actual) {
          final expected = row[key] == null ? null : DateTime.parse(row[key]);
          if (expected == null || actual == null) {
            if (expected != actual) {
              failures.add(
                '${row['id']} ${row['date']} $key $actual vs $expected',
              );
            }
            return;
          }
          if (actual.difference(expected).inMilliseconds.abs() > 1000) {
            failures.add(
              '${row['id']} ${row['date']} $key $actual vs $expected',
            );
          }
        }

        compare('sunrise', day.sunriseUtc);
        compare('moonrise', day.moonriseUtc);
        compare('moonset', day.moonsetUtc);
        // The engine reports the sunset that follows sunrise (which can fall
        // after midnight in polar summer); compare only same-day ordering.
        final sunrise = row['sunrise'], sunset = row['sunset'];
        if (sunrise != null &&
            sunset != null &&
            (sunset as String).compareTo(sunrise) > 0) {
          compare('sunset', day.sunsetUtc);
        }
        if (row['tithi'] != null && day.tithi.index != row['tithi']) {
          failures.add(
            '${row['id']} ${row['date']} tithi ${day.tithi.index} vs ${row['tithi']}',
          );
        }
      }
      expect(failures, isEmpty);
    },
  );

  test('Delhi 2027 Smarta fasts and Parana match published Drik data', () {
    final data =
        jsonDecode(File('assets/calendar/2027.json').readAsStringSync()) as Map;
    final fasts = {
      for (final fast in const CalculatedEkadashiEngine().calculate(
        DateTime.utc(2027),
        365,
        PanchangCity.newDelhi,
        EkadashiTradition.smarta,
      ))
        fast.date.toIso8601String().substring(0, 10): fast,
    };
    for (final entry in data['ekadashis'] as List) {
      final timing = entry['timing']['IST'] as Map;
      final fast = fasts[timing['date']];
      expect(
        fast,
        isNotNull,
        reason: '${entry['name']['en']} ${timing['date']}',
      );
      double minutes(DateTime? actual, String expected) =>
          actual!.difference(DateTime.parse(expected)).inSeconds.abs() / 60;
      expect(
        minutes(fast!.paranaStartUtc, timing['parana_start']),
        lessThanOrEqualTo(2),
        reason: 'Parana start ${timing['date']}',
      );
      expect(
        minutes(fast.paranaEndUtc, timing['parana_end']),
        lessThanOrEqualTo(2),
        reason: 'Parana end ${timing['date']}',
      );
    }
    // No extra fasts inside the published range (the pack ends on Dec 9).
    final published = {
      for (final entry in data['ekadashis'] as List)
        entry['timing']['IST']['date'] as String,
    };
    final last = published.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    expect(fasts.keys.where((d) => d.compareTo(last) <= 0).toSet(), published);
  });

  test('Smarta skipped and repeated Ekadashi follow Drik (Chennai 2026)', () {
    final dates = {
      for (final fast in const CalculatedEkadashiEngine().calculate(
        DateTime.utc(2026, 5, 20),
        200,
        chennai,
        EkadashiTradition.smarta,
      ))
        fast.date.toIso8601String().substring(0, 10),
    };
    // Repeated Ekadashi with Dwadashi also extended: the second day.
    expect(dates, contains('2026-05-27'));
    expect(dates, isNot(contains('2026-05-26')));
    // Ekadashi touching no sunrise: the day it begins.
    expect(dates, contains('2026-07-10'));
    expect(dates, isNot(contains('2026-07-11')));
    // Dwadashi touching no sunrise: the day before, so Parana is in Dwadashi.
    expect(dates, contains('2026-11-20'));
    expect(dates, isNot(contains('2026-11-21')));
  });

  test('Gaudiya fasts match the ISKCON Bangalore published calendar', () {
    // https://www.iskconbangalore.org/ekadashi-calendar/ (March 2026 to
    // March 2027), with its special cases noted.
    const published = {
      '2026-03-15': null,
      '2026-03-29': null,
      '2026-04-13': null,
      '2026-04-27': null,
      '2026-05-13': null,
      '2026-05-27': null,
      '2026-06-11': null,
      '2026-06-25': null,
      '2026-07-11': 'Viddha / shifted to Dwadashi',
      '2026-07-25': null,
      '2026-08-09': null,
      '2026-08-24': 'Vyanjuli',
      '2026-09-07': null,
      '2026-09-22': null,
      '2026-10-06': null,
      '2026-10-22': null,
      '2026-11-05': null,
      '2026-11-21': 'Trisprisha',
      '2026-12-04': null,
      '2026-12-20': null,
      '2027-01-03': null,
      '2027-01-19': 'Trisprisha',
      '2027-02-02': null,
      '2027-02-17': null,
      '2027-03-04': 'Unmilani',
      '2027-03-18': null,
    };
    const bengaluru = PanchangCity(
      id: 'bengaluru',
      label: 'Bengaluru',
      latitude: 12.9716,
      longitude: 77.5946,
    );
    final fasts = {
      for (final start in [DateTime.utc(2026, 3, 10), DateTime.utc(2027)])
        for (final fast in const CalculatedEkadashiEngine().calculate(
          start,
          start.year == 2026 ? 300 : 90,
          bengaluru,
          EkadashiTradition.gaudiya,
        ))
          fast.date.toIso8601String().substring(0, 10): fast.rule,
    };
    final inRange = {
      for (final entry in fasts.entries)
        if (entry.key.compareTo('2026-03-15') >= 0 &&
            entry.key.compareTo('2027-03-18') <= 0)
          entry.key: entry.value,
    };
    expect(inRange.keys.toSet(), published.keys.toSet());
    published.forEach((date, rule) {
      if (rule != null) expect(inRange[date], rule, reason: date);
    });
  });

  test('festival dates match public Indian lists (New Delhi 2026-2027)', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/panchang/festivals_india_2026_2027.json',
              ).readAsStringSync(),
            )
            as Map;
    String? key(String id, String name) => switch (id) {
      'vinayaka-chaturthi' =>
        name == 'Ganesh Chaturthi' ? 'ganesh-chaturthi' : null,
      'sankranti-9' => 'makar-sankranti',
      'sankranti-0' => 'mesha-sankranti',
      _ => id,
    };
    final cache = <String, List<String>>{};
    List<String> keysOn(DateTime date) => cache[date.toIso8601String()] ??= [
      for (final event in engine.calculate(date).observances)
        ?key(event.id, event.name),
    ];
    final failures = <String>[];
    (fixture['festivals'] as Map).forEach((festival, accepted) {
      final dates = (accepted as List).cast<String>();
      for (final year in {for (final d in dates) d.substring(0, 4)}) {
        final want = dates.where((d) => d.startsWith(year)).toSet();
        final first = DateTime.parse(
          want.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
        );
        final found = <String>[];
        for (var offset = -3; offset <= 4; offset++) {
          final day = first.add(Duration(days: offset));
          if (keysOn(day).contains(festival)) {
            found.add(day.toIso8601String().substring(0, 10));
          }
        }
        if (found.length != 1 || !want.contains(found.single)) {
          failures.add('$festival $year: found $found, accepted $want');
        }
      }
    });
    expect(failures, isEmpty);
  });

  test('Makar Sankranti after sunset is observed on the next day', () {
    final ingressDay = engine.calculate(DateTime.utc(2027, 1, 14));
    final nextDay = engine.calculate(DateTime.utc(2027, 1, 15));
    expect(
      ingressDay.observances.map((event) => event.name),
      isNot(contains('Makar Sankranti')),
    );
    expect(
      nextDay.observances.map((event) => event.name),
      contains('Makar Sankranti'),
    );
  });

  test('sunset just after local midnight belongs to the solar day', () {
    const reykjavik = PanchangCity(
      id: 'reykjavik',
      label: 'Reykjavik',
      latitude: 64.1466,
      longitude: -21.9426,
      timeZoneId: 'Atlantic/Reykjavik',
    );
    // 16 June 2026 has no sunset before midnight; the Sun sets at 00:00:52
    // on the 17th (Swiss Ephemeris), which ends the 16th's solar day.
    final day = engine.calculate(DateTime.utc(2026, 6, 16), city: reykjavik);
    expect(day.sunsetUtc, isNotNull);
    expect(
      day.sunsetUtc!
          .difference(DateTime.utc(2026, 6, 17, 0, 0, 52))
          .inSeconds
          .abs(),
      lessThanOrEqualTo(1),
    );
    expect(day.rahukala, isNotNull);
  });

  test('Sankranti is shown on polar days without sunrise or sunset', () {
    const longyearbyen = PanchangCity(
      id: 'longyearbyen',
      label: 'Longyearbyen',
      latitude: 78.2232,
      longitude: 15.6267,
      timeZoneId: 'Arctic/Longyearbyen',
    );
    // Polar night: no sunrise. Dhanu Sankranti 2026 is on 16 December.
    final day = engine.calculate(
      DateTime.utc(2026, 12, 16),
      city: longyearbyen,
    );
    expect(day.sunriseUtc, isNull);
    expect(day.observances.map((event) => event.id), contains('sankranti-8'));
    // Polar day: no sunset. Mithuna Sankranti 2026 is on 15 June.
    final summer = engine.calculate(
      DateTime.utc(2026, 6, 15),
      city: longyearbyen,
    );
    expect(summer.sunsetUtc, isNull);
    expect(
      summer.observances.map((event) => event.id),
      contains('sankranti-2'),
    );
  });

  test('time zones follow IANA 2026b (British Columbia stays on UTC-7)', () {
    const vancouver = PanchangCity(
      id: 'vancouver',
      label: 'Vancouver',
      latitude: 49.2827,
      longitude: -123.1207,
      timeZoneId: 'America/Vancouver',
    );
    // tzdata 2026b: no fall-back on 2026-11-01; PST would be UTC-8.
    final december = vancouver.wallClock(DateTime.utc(2026, 12, 1, 12));
    expect(december.timeZoneOffset, const Duration(hours: -7));
    // Sunrise on 1 December is shown on the UTC-7 civil day.
    final day = engine.calculate(DateTime.utc(2026, 12, 1), city: vancouver);
    expect(vancouver.wallClock(day.sunriseUtc!).hour, 8);
  });

  test('New York 2026 Mesha Sankranti falls on its local civil date', () {
    List<String> ids(int day) => [
      for (final event
          in engine
              .calculate(DateTime.utc(2026, 4, day), city: PanchangCity.newYork)
              .observances)
        event.id,
    ];
    expect(ids(13), isNot(contains('sankranti-0')));
    expect(ids(14), contains('sankranti-0'));
  });
}
