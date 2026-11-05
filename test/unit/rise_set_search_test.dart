import 'package:ekadashi_calendar/services/panchang/astronomy_calculator.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/time_zone_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sunrise, sunset, moonrise and moonset skip ahead where the body is far
/// from the horizon (altitude changes by at most 0.3° a minute), instead of
/// scanning every 5 minutes: the same instants, faster
/// (RiseSetSearchTests.swift).
void main() {
  setUpAll(initializeTimeZoneData);
  const engine = PanchangEngine();

  /// The 5-minute scan the engine used before October 2026, as the reference.
  DateTime? scan(
    DateTime start,
    DateTime end,
    PanchangCity city,
    bool moon,
    bool rising,
  ) {
    double difference(DateTime instant) {
      final altitude = AstronomyCalculator.altitudeDegrees(
        instant: instant,
        latitude: city.latitude,
        longitude: city.longitude,
        moon: moon,
      );
      return moon
          ? altitude
          : altitude +
                AstronomyCalculator.horizonRefraction +
                AstronomyCalculator.semidiameterDegrees(instant, moon: false);
    }

    const step = Duration(minutes: 5);
    var low = start;
    var lowValue = difference(low);
    for (var next = start.add(step); low.isBefore(end); next = next.add(step)) {
      final high = next.isAfter(end) ? end : next;
      final highValue = difference(high);
      if (rising
          ? lowValue <= 0 && highValue > 0
          : lowValue >= 0 && highValue < 0) {
        var left = low, right = high;
        for (var i = 0; i < 20; i++) {
          final middle = left.add(right.difference(left) ~/ 2);
          final value = difference(middle);
          if (rising ? value > 0 : value < 0) {
            right = middle;
          } else {
            left = middle;
          }
        }
        return right;
      }
      low = high;
      lowValue = highValue;
    }
    return null;
  }

  const cities = [
    PanchangCity.newDelhi,
    PanchangCity.chennai,
    PanchangCity.london,
    PanchangCity.newYork,
    PanchangCity.sydney,
    PanchangCity(
      id: 'tromso',
      label: 'Tromso',
      latitude: 69.6492,
      longitude: 18.9553,
      timeZoneId: 'Europe/Oslo',
    ),
    PanchangCity(
      id: 'reykjavik',
      label: 'Reykjavik',
      latitude: 64.1466,
      longitude: -21.9426,
      timeZoneId: 'Atlantic/Reykjavik',
    ),
  ];
  final days = [
    DateTime.utc(1900, 3, 1),
    DateTime.utc(2026, 1, 15),
    DateTime.utc(2026, 6, 21),
    DateTime.utc(2026, 10, 30),
    DateTime.utc(2027, 3, 20),
    DateTime.utc(2027, 12, 21),
    DateTime.utc(2100, 6, 21),
  ];

  void each(
    DateTime? Function(DateTime, DateTime, PanchangCity, bool, bool) search,
    void Function(String, DateTime?)? check,
  ) {
    for (final city in cities) {
      for (final day in days) {
        for (final moon in const [false, true]) {
          for (final rising in const [true, false]) {
            final found = search(
              city.midnight(day),
              city.midnight(day, dayOffset: 1),
              city,
              moon,
              rising,
            );
            check?.call('${city.id} $day moon $moon rising $rising', found);
          }
        }
      }
    }
  }

  test('crossings match the scan', () {
    final expected = <String, DateTime?>{};
    each(scan, (label, found) => expected[label] = found);
    each(
      (start, end, city, moon, rising) =>
          engine.findCrossing(start, end, city, moon: moon, rising: rising),
      (label, found) {
        final want = expected[label];
        if (want == null || found == null) {
          expect(found == null, want == null, reason: label);
        } else {
          expect(
            found.difference(want).inMicroseconds.abs(),
            lessThan(1000),
            reason: label,
          );
        }
      },
    );
  });

  test('crossings are faster than the scan', () {
    int time(void Function() body) {
      final watch = Stopwatch()..start();
      body();
      return watch.elapsedMicroseconds;
    }

    each(scan, null); // warm up
    final old = time(() => each(scan, null));
    final now = time(
      () => each(
        (start, end, city, moon, rising) =>
            engine.findCrossing(start, end, city, moon: moon, rising: rising),
        null,
      ),
    );
    expect(now, lessThan(old * 0.6), reason: 'new $now µs, scan $old µs');
  });
}
