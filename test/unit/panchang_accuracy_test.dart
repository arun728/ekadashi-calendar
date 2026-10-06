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
