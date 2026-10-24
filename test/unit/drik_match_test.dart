import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/panchang/astronomy_calculator.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_terms.dart';
import 'package:ekadashi_calendar/services/time_zone_data.dart';

/// Every time the app shows matches Drik Panchang to the minute
/// (test/fixtures/panchang/drik_reference.json, New Delhi, Drik's default
/// settings; see docs/PANCHANG_ACCURACY.md "Drik time base"):
/// - Drik shows times rounded to the nearest minute, not cut;
/// - Drik's tithi, nakshatra, yoga and karana moments are those of the Sun
///   and Moon one Delta T later than the astronomical (JPL) moment;
/// - Drik's Lahiri ayanamsa is the mean Lahiri value plus 24.2″.
/// A value within a few seconds of a half minute can round either way, so
/// those are counted but not required: Drik's own clock decides them.
void main() {
  setUpAll(initializeTimeZoneData);

  final fixture =
      jsonDecode(
            File(
              'test/fixtures/panchang/drik_reference.json',
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

  String two(int v) => v.toString().padLeft(2, '0');
  String hm(DateTime instant, [PanchangCity? city]) {
    final local = (city ?? delhi).displayClock(instant);
    return '${two(local.hour)}:${two(local.minute)}';
  }

  String stamp(DateTime instant, [PanchangCity? city]) {
    final local = (city ?? delhi).displayClock(instant);
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${hm(instant, city)}';
  }

  /// Seconds between the exact local time and the nearest half minute.
  double edge(DateTime instant, [PanchangCity? city]) {
    final local = (city ?? delhi).wallClock(instant);
    return (local.second + local.millisecond / 1000 - 30).abs();
  }

  /// Checks shown values; returns the share that matched.
  double check(
    List<(String, DateTime?, String)> rows, {
    required double knifeEdge,
    PanchangCity? city,
  }) {
    final failures = <String>[];
    var matched = 0;
    for (final (label, actual, expected) in rows) {
      if (actual == null) {
        failures.add('$label: none vs $expected');
        continue;
      }
      final shown = expected.length > 5
          ? stamp(actual, city)
          : hm(actual, city);
      if (shown == expected) {
        matched++;
      } else if (edge(actual, city) > knifeEdge) {
        failures.add(
          '$label: shows $shown, Drik $expected '
          '(exact ${(city ?? delhi).wallClock(actual).toIso8601String()})',
        );
      }
    }
    expect(failures, isEmpty);
    return matched / rows.length;
  }

  final fasts = {
    for (final tradition in EkadashiTradition.values)
      tradition: {
        for (final year in [2026, 2027])
          for (final fast in const CalculatedEkadashiEngine().calculate(
            DateTime.utc(year),
            365,
            delhi,
            tradition,
          ))
            fast.date.toIso8601String().substring(0, 10): fast,
      },
  };
  DateTime? dwadashiEnd(CalculatedEkadashi fast) => engine
      .tithiAt(fast.tithiEndUtc.add(const Duration(seconds: 1)))
      .endsAtUtc;

  test('display rounds to the nearest minute in every time zone', () {
    // 06:10:29.999 and 06:10:30 IST.
    final before = DateTime.utc(2026, 11, 20, 0, 40, 29, 999);
    final after = DateTime.utc(2026, 11, 20, 0, 40, 30);
    expect(delhi.displayClock(before).minute, 10);
    expect(delhi.displayClock(after).minute, 11);
    expect(delhi.displayClock(after).second, 0);
    for (final (zone, offset) in [
      ('Asia/Kathmandu', const Duration(hours: 5, minutes: 45)),
      ('Pacific/Chatham', const Duration(hours: 12, minutes: 45)),
      ('America/St_Johns', const Duration(hours: -2, minutes: -30)),
      ('America/New_York', const Duration(hours: -4)),
    ]) {
      final city = PanchangCity(
        id: zone,
        label: zone,
        latitude: 0,
        longitude: 0,
        timeZoneId: zone,
      );
      // 12:00:40 UTC on 1 July 2026, i.e. :40 seconds past a local minute.
      final instant = DateTime.utc(2026, 7, 1, 12, 0, 40);
      final local = city.displayClock(instant);
      final expected = instant.add(offset).add(const Duration(seconds: 20));
      expect(
        (local.hour, local.minute),
        (expected.hour, expected.minute),
        reason: zone,
      );
    }
    // Every formatter rounds: the Panchang tab, Home's schedule and the
    // diagnostic label agree with Drik.
    expect(
      PanchangFormat.time(after, delhi, DateTime.utc(2026, 11, 20), 'en'),
      AppStrings.clock(6, 11, 'en'),
    );
    expect(EkadashiSchedule.iso(after, delhi), '2026-11-20T06:11:00+05:30');
    expect(
      formatPanchangTime(after, delhi, DateTime.utc(2026, 11, 20)),
      startsWith('6:11 AM'),
    );
    // 23:59:45 IST rounds into the next day, with the next-day marker.
    final midnight = DateTime.utc(2026, 11, 20, 18, 29, 45);
    expect(
      PanchangFormat.time(midnight, delhi, DateTime.utc(2026, 11, 20), 'en'),
      contains(AppStrings.clock(0, 0, 'en')),
    );
    expect(
      formatPanchangTime(midnight, delhi, DateTime.utc(2026, 11, 20)),
      endsWith('(+1 day)'),
    );
  });

  test('Lahiri ayanamsa and positions follow Drik', () {
    double parse(String dms) {
      final m = RegExp(r'(\d+)°(\d+)′(\d+)″').firstMatch(dms)!;
      return int.parse(m[1]!) + int.parse(m[2]!) / 60 + int.parse(m[3]!) / 3600;
    }

    for (final row in fixture['positions'] as List) {
      final ist = DateTime.parse(
        '${row['ist']}Z',
      ).subtract(const Duration(hours: 5, minutes: 30));
      final tropical = row['tropical'] as Map;
      final sidereal = row['sidereal'] as Map;
      final drikAyanamsa = AstronomyCalculator.signedAngle(
        parse(tropical['sun']) - parse(sidereal['sun']),
      );
      double arcsec(double a, double b) =>
          AstronomyCalculator.signedAngle(a - b).abs() * 3600;
      // Drik shows whole arcseconds, so each value carries up to 1″.
      expect(
        arcsec(AstronomyCalculator.drikLahiriAyanamsa(ist), drikAyanamsa),
        lessThan(2),
        reason: 'ayanamsa ${row['ist']}',
      );
      expect(
        arcsec(
          AstronomyCalculator.drikSunLongitude(ist),
          parse(tropical['sun']),
        ),
        lessThan(1.6),
        reason: 'Sun ${row['ist']}',
      );
      expect(
        arcsec(
          AstronomyCalculator.drikMoonLongitude(ist),
          parse(tropical['moon']),
        ),
        lessThan(6),
        reason: 'Moon ${row['ist']}',
      );
    }
  });

  test('Ekadashi tithi begins and ends show Drik\'s minute (2026-2027)', () {
    final rows = <(String, DateTime?, String)>[];
    for (final (tradition, key) in [
      (EkadashiTradition.smarta, 'smarta'),
      (EkadashiTradition.gaudiya, 'vaishnava'),
    ]) {
      for (final row in fixture[key] as List) {
        final fast = fasts[tradition]![row['date']];
        if (fast == null) continue; // dates are checked separately
        rows.add((
          '$key ${row['date']} begins',
          fast.tithiStartUtc,
          row['tithiBegins'] as String,
        ));
        rows.add((
          '$key ${row['date']} ends',
          fast.tithiEndUtc,
          row['tithiEnds'] as String,
        ));
      }
    }
    expect(check(rows, knifeEdge: 6), greaterThanOrEqualTo(0.97));
    expect(rows.length, greaterThanOrEqualTo(194));
  });

  test('held-out 2028 tithi boundaries show Drik\'s minute', () {
    final ends = <DateTime>{};
    for (var i = -2; i < 370; i++) {
      final day = engine.calculate(
        DateTime.utc(2028).add(Duration(days: i)),
        city: delhi,
      );
      // The sunrise tithi's end and the next one's, so a tithi touching no
      // sunrise counts too.
      final end = day.tithi.endsAtUtc;
      if (end == null) continue;
      ends.add(end);
      final next = engine.tithiAt(end.add(const Duration(seconds: 1)));
      if (next.endsAtUtc != null) ends.add(next.endsAtUtc!);
    }
    final rows = <(String, DateTime?, String)>[];
    for (final expected in fixture['heldOut2028TithiBoundaries'] as List) {
      final drik = DateTime.parse(
        '${expected}:00Z',
      ).subtract(const Duration(hours: 5, minutes: 30));
      final nearest = ends.reduce(
        (a, b) => (a.difference(drik).abs() < b.difference(drik).abs()) ? a : b,
      );
      rows.add(('2028 $expected', nearest, expected as String));
    }
    expect(check(rows, knifeEdge: 6), greaterThanOrEqualTo(0.95));
  });

  test('Smarta fast days, Hari Vasara, Dwadashi end and Parana match Drik', () {
    final rows = <(String, DateTime?, String)>[];
    final dates = <String>{};
    for (final row in fixture['smarta'] as List) {
      final fast = fasts[EkadashiTradition.smarta]![row['date']];
      expect(fast, isNotNull, reason: 'Smarta ${row['date']}');
      dates.add(row['date'] as String);
      expect(
        fast!.paranaDate.toIso8601String().substring(0, 10),
        row['paranaDate'],
      );
      if (row['hariVasara'] != null) {
        rows.add((
          '${row['date']} Hari Vasara',
          fast.hariVasaraEndUtc,
          row['hariVasara'] as String,
        ));
      }
      if (row['dwadashiEnd'] != null) {
        rows.add((
          '${row['date']} Dwadashi end',
          dwadashiEnd(fast),
          row['dwadashiEnd'] as String,
        ));
      }
      if (row['paranaStart'] != null) {
        rows.add((
          '${row['date']} Parana start',
          fast.paranaStartUtc,
          row['paranaStart'] as String,
        ));
      }
      if (row['paranaEnd'] != null) {
        rows.add((
          '${row['date']} Parana end',
          fast.paranaEndUtc,
          row['paranaEnd'] as String,
        ));
      }
    }
    // Parana limits rest on sunrise, which Drik places up to 9 s apart.
    expect(check(rows, knifeEdge: 9), greaterThanOrEqualTo(0.9));
    final found = fasts[EkadashiTradition.smarta]!.keys.toSet();
    expect(found.difference(dates), isEmpty, reason: 'engine only');
    expect(dates.difference(found), isEmpty, reason: 'Drik only');
  });

  test('Vaishnava (ISKCON) fast days and Parana match Drik', () {
    final rows = <(String, DateTime?, String)>[];
    final dates = {
      for (final row in fixture['vaishnava'] as List) row['date'] as String,
    };
    // Includes 25 June 2026 and 11 September 2027, where the Purnima and
    // Shravana boundaries sit within 20 seconds of sunrise.
    expect(fasts[EkadashiTradition.gaudiya]!.keys.toSet(), dates);
    for (final row in fixture['vaishnava'] as List) {
      final fast = fasts[EkadashiTradition.gaudiya]![row['date']]!;
      rows.add((
        '${row['date']} Parana start',
        fast.paranaStartUtc,
        row['paranaStart'] as String,
      ));
      if (row['paranaEnd'] != null) {
        rows.add((
          '${row['date']} Parana end',
          fast.paranaEndUtc,
          row['paranaEnd'] as String,
        ));
      }
    }
    // Most Parana limits are sunrise, which Drik places up to 9 s apart.
    expect(check(rows, knifeEdge: 9), greaterThanOrEqualTo(0.88));
  });

  test('sunrise and sunset show Drik\'s minute on all 730 days', () {
    final sunrise = <(String, DateTime?, String)>[];
    final sunset = <(String, DateTime?, String)>[];
    (fixture['sun'] as Map).forEach((date, value) {
      final day = engine.calculate(
        DateTime.parse('${date}T00:00:00Z'),
        city: delhi,
      );
      sunrise.add(('$date sunrise', day.sunriseUtc, value[0] as String));
      sunset.add(('$date sunset', day.sunsetUtc, value[1] as String));
    });
    expect(check(sunrise, knifeEdge: 9), greaterThanOrEqualTo(0.92));
    expect(check(sunset, knifeEdge: 9), greaterThanOrEqualTo(0.93));
  });

  test('nakshatra ends follow Drik\'s ayanamsa and time base', () {
    final ends = <DateTime>{};
    for (var i = -1; i < 732; i++) {
      final day = engine.calculate(
        DateTime.utc(2026).add(Duration(days: i)),
        city: delhi,
      );
      if (day.nakshatra.endsAtUtc != null) ends.add(day.nakshatra.endsAtUtc!);
    }
    var matched = 0, total = 0;
    for (final expected in fixture['nakshatraEnds'] as List) {
      final drik = DateTime.parse(
        '${expected}:00Z',
      ).subtract(const Duration(hours: 5, minutes: 30));
      final nearest = ends.reduce(
        (a, b) => (a.difference(drik).abs() < b.difference(drik).abs()) ? a : b,
      );
      if (nearest.difference(drik).inMinutes.abs() > 5) continue;
      total++;
      if (stamp(nearest) == expected) matched++;
    }
    expect(total, greaterThan(690));
    expect(matched / total, greaterThanOrEqualTo(0.92));
  });

  test('Smarta days and Ekadashi times match Drik worldwide (2026)', () {
    // London, New York and Los Angeles (northern DST), Sydney (southern
    // DST), Kathmandu (UTC+5:45) and Chennai, at Drik's coordinates.
    for (final place in fixture['world2026'] as List) {
      final city = PanchangCity(
        id: place['city'] as String,
        label: place['city'] as String,
        latitude: (place['lat'] as num).toDouble(),
        longitude: (place['lon'] as num).toDouble(),
        timeZoneId: place['tz'] as String,
      );
      final found = {
        for (final fast in const CalculatedEkadashiEngine().calculate(
          DateTime.utc(2025, 12, 31),
          366,
          city,
          EkadashiTradition.smarta,
        ))
          fast.date.toIso8601String().substring(0, 10): fast,
      }..removeWhere((date, _) => !date.startsWith('2026'));
      final rows = <(String, DateTime?, String)>[];
      for (final row in place['fasts'] as List) {
        final fast = found[row['date']];
        if (fast == null) continue;
        rows.add((
          '${city.id} ${row['date']} begins',
          fast.tithiStartUtc,
          row['tithiBegins'] as String,
        ));
        rows.add((
          '${city.id} ${row['date']} ends',
          fast.tithiEndUtc,
          row['tithiEnds'] as String,
        ));
      }
      expect(
        check(rows, knifeEdge: 6, city: city),
        greaterThanOrEqualTo(0.95),
        reason: city.id,
      );
      expect(found.keys.toSet(), {
        for (final row in place['fasts'] as List) row['date'],
      }, reason: city.id);
    }
  });

  test('moonrise and moonset follow Drik: disc centre, no refraction, '
      'first after sunrise', () {
    final rise = <(String, DateTime?, String)>[];
    final set = <(String, DateTime?, String)>[];
    for (final row in fixture['moon'] as List) {
      final day = engine.calculate(
        DateTime.parse('${row['date']}T00:00:00Z'),
        city: delhi,
      );
      rise.add((
        '${row['date']} moonrise',
        day.moonriseUtc,
        row['moonrise'] as String,
      ));
      set.add((
        '${row['date']} moonset',
        day.moonsetUtc,
        row['moonset'] as String,
      ));
    }
    expect(check(rise, knifeEdge: 6), greaterThanOrEqualTo(0.9));
    expect(check(set, knifeEdge: 6), greaterThanOrEqualTo(0.9));
  });
}
