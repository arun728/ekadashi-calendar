import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/time_zone_data.dart';

/// Vaishnava (ISKCON) fasts and Parana match GCal 11, the GBC Calendar
/// Committee's program that ISKCON calendars are made with, as published by
/// vaisnavacalendar.info for 67 cities worldwide in 2026 and 2027
/// (test/fixtures/panchang/gcal11_ekadashi_2026_2027.json,
/// IskconParityTests.swift). GCal shows times cut to the minute in local time.
void main() {
  setUpAll(initializeTimeZoneData);

  final cities =
      (jsonDecode(
                File(
                  'test/fixtures/panchang/gcal11_ekadashi_2026_2027.json',
                ).readAsStringSync(),
              )
              as Map)['cities']
          as List;

  PanchangCity city(Map row) => PanchangCity(
    id: row['name'] as String,
    label: row['name'] as String,
    latitude: (row['lat'] as num).toDouble(),
    longitude: (row['lon'] as num).toDouble(),
    timeZoneId: row['tz'] as String,
  );

  Map<String, CalculatedEkadashi> fasts(PanchangCity place, int year) => {
    for (final fast in const CalculatedEkadashiEngine().calculate(
      DateTime.utc(year),
      DateTime.utc(year + 1).difference(DateTime.utc(year)).inDays,
      place,
      EkadashiTradition.gaudiya,
    ))
      fast.date.toIso8601String().substring(0, 10): fast,
  };

  String two(int v) => v.toString().padLeft(2, '0');
  String? shown(DateTime? instant, PanchangCity place) {
    if (instant == null) return null;
    final wall = place.displayClock(instant);
    return '${two(wall.hour)}:${two(wall.minute)}';
  }

  int minutes(String? text) => text == null
      ? -9999
      : int.parse(text.substring(0, 2)) * 60 + int.parse(text.substring(3));

  test('fast days match GCal 11 in 67 cities', () {
    final failures = <String>[];
    var total = 0;
    for (final row in cities.cast<Map>()) {
      final place = city(row);
      (row['years'] as Map).forEach((year, list) {
        final expected = {for (final f in list as List) f['date'] as String};
        final found = fasts(place, int.parse(year as String)).keys.toSet();
        total += expected.length;
        if (found.length != expected.length || !found.containsAll(expected)) {
          failures.add(
            '${place.id} $year: engine only ${found.difference(expected)}, '
            'GCal only ${expected.difference(found)}',
          );
        }
      });
    }
    expect(total, greaterThan(3000));
    expect(failures, isEmpty);
  });

  test('Parana matches GCal 11 to the minute', () {
    var matched = 0, total = 0;
    final far = <String>[];
    for (final row in cities.cast<Map>()) {
      final place = city(row);
      (row['years'] as Map).forEach((year, list) {
        final found = fasts(place, int.parse(year as String));
        for (final gcal in (list as List).cast<Map>()) {
          final fast = found[gcal['date']];
          if (fast == null) continue;
          expect(
            fast.paranaDate.toIso8601String().substring(0, 10),
            gcal['paranaDate'],
            reason: '${place.id} ${gcal['date']}',
          );
          for (final (want, actual) in [
            (gcal['paranaStart'] as String?, fast.paranaStartUtc),
            (gcal['paranaEnd'] as String?, fast.paranaEndUtc),
          ]) {
            if (want == null) continue;
            total++;
            final got = shown(actual, place);
            if (got == want) {
              matched++;
            } else if ((minutes(got) - minutes(want)).abs() > 1) {
              // Only a GCal build difference of seconds may remain.
              far.add('${place.id} ${gcal['date']}: $got vs $want');
            }
          }
        }
      });
    }
    expect(total, greaterThan(6000));
    expect(far, isEmpty);
    expect(
      matched / total,
      greaterThanOrEqualTo(0.99),
      reason: '$matched/$total',
    );
  });
}
