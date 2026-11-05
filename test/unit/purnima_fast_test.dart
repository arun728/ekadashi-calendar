import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/time_zone_data.dart';

/// Purnima is listed once, on its fast (Upavasa) day, as Drik Panchang,
/// Prokerala and AstroSage list it: the day Purnima begins if it has begun
/// by the end of that day's Madhyahna (three fifths of daylight), else the
/// next day (test/fixtures/panchang/purnima_fasts.json, PurnimaFastTests).
void main() {
  setUpAll(initializeTimeZoneData);

  final fixture =
      jsonDecode(
            File(
              'test/fixtures/panchang/purnima_fasts.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final c = fixture['city'] as Map<String, dynamic>;
  final delhi = PanchangCity(
    id: c['id'] as String,
    label: c['label'] as String,
    latitude: (c['lat'] as num).toDouble(),
    longitude: (c['lon'] as num).toDouble(),
    timeZoneId: c['tz'] as String,
  );
  const engine = PanchangEngine();
  bool isPurnima(DateTime date) => engine
      .calculate(date, city: delhi)
      .observances
      .any((event) => event.id == 'purnima');

  test('Purnima is listed on its fast day only', () {
    final failures = <String>[];
    for (final row in fixture['fasts'] as List) {
      final date = DateTime.parse('${row['date']}T00:00:00Z');
      if (!isPurnima(date)) failures.add('${row['date']}: not Purnima');
      for (final other in [
        date.subtract(const Duration(days: 1)),
        date.add(const Duration(days: 1)),
      ]) {
        if (isPurnima(other)) {
          failures.add('${row['date']}: Purnima also on $other');
        }
      }
    }
    expect(failures, isEmpty);
  });

  test('Sharad Purnima 2026 is the fast day, not the next day', () {
    expect(isPurnima(DateTime.utc(2026, 10, 25)), isTrue);
    expect(isPurnima(DateTime.utc(2026, 10, 26)), isFalse);
  });

  test('Purnima is listed once per lunar month', () {
    for (final (year, count) in [(2026, 13), (2027, 12)]) {
      var found = 0;
      for (
        var day = DateTime.utc(year);
        day.year == year;
        day = day.add(const Duration(days: 1))
      ) {
        if (isPurnima(day)) found++;
      }
      expect(found, count, reason: '$year');
    }
  });
}
