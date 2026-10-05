import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';

void main() {
  const engine = PanchangEngine();
  const ny = PanchangCity(
    id: 'ny',
    label: 'New York',
    latitude: 40.7128,
    longitude: -74.006,
    timeZoneId: 'America/New_York',
  );
  test('civil boundaries follow selected timezone including DST', () {
    final spring = DateTime.utc(2026, 3, 8);
    final fall = DateTime.utc(2026, 11, 1);
    expect(
      engine
          .endFor(spring, city: ny)
          .difference(engine.startFor(spring, city: ny))
          .inHours,
      23,
    );
    expect(
      engine
          .endFor(fall, city: ny)
          .difference(engine.startFor(fall, city: ny))
          .inHours,
      25,
    );
    expect(engine.startFor(spring, city: ny), DateTime.utc(2026, 3, 8, 5));
    final day = engine.calculate(spring, city: ny);
    expect(ny.wallClock(day.sunriseUtc!).hour, inInclusiveRange(6, 8));
    expect(ny.wallClock(day.sunriseUtc!).day, 8);
  });
  test('New York rise and set agree with independent USNO fixture', () {
    // USNO one-day API: 2026-10-04, 40.7128,-74.006, UTC-4.
    final day = engine.calculate(DateTime.utc(2026, 10, 4), city: ny);
    int minutes(DateTime instant) {
      final local = ny.wallClock(instant);
      return local.hour * 60 + local.minute;
    }

    expect(minutes(day.sunriseUtc!), closeTo(6 * 60 + 56, 4));
    expect(minutes(day.sunsetUtc!), closeTo(18 * 60 + 33, 4));
    expect(minutes(day.moonsetUtc!), closeTo(15 * 60 + 30, 5));
    expect(
      day.moonriseUtc,
      isNull,
    ); // The Moon does not rise on every civil day.
  });
  test('invalid coordinates and timezone rejected', () {
    for (final lat in [91.0, double.nan, double.infinity]) {
      expect(
        () => engine.calculate(
          DateTime(2026),
          city: PanchangCity(id: 'x', label: 'X', latitude: lat, longitude: 0),
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => engine.calculate(
        DateTime(2026),
        city: const PanchangCity(
          id: 'x',
          label: 'X',
          latitude: 0,
          longitude: 0,
          timeZoneId: 'EST',
        ),
      ),
      throwsArgumentError,
    );
  });
  test('Monday Rahu is second eighth and Sunday is eighth', () {
    for (final entry in {5: 1, 4: 7}.entries) {
      final day = engine.calculate(DateTime.utc(2026, 10, entry.key));
      final eighth = day.sunsetUtc!.difference(day.sunriseUtc!) ~/ 8;
      expect(day.rahukala!.startUtc, day.sunriseUtc!.add(eighth * entry.value));
    }
  });
  test(
    'details include moonset, rashis, contiguous Choghadiya and transitions',
    () {
      final day = engine.calculate(DateTime.utc(2026, 10, 4), city: ny);
      expect(day.moonsetUtc, isNotNull);
      expect(day.sunRashi, isNotEmpty);
      expect(day.moonRashi, isNotEmpty);
      expect(day.abhijit, isNotNull);
      expect(day.brahmaMuhurta!.endUtc.isBefore(day.sunriseUtc!), isTrue);
      expect(day.choghadiya.length, 16);
      for (var i = 1; i < 16; i++) {
        expect(day.choghadiya[i].startUtc, day.choghadiya[i - 1].endUtc);
      }
      expect(day.choghadiya.first.startUtc, day.sunriseUtc);
      expect(day.choghadiya.last.endUtc, day.nextSunriseUtc);
      expect(day.limbTimeline['Karana']!.length, greaterThan(1));
    },
  );
  test('polar day has no fabricated sunrise periods or observances', () {
    final day = engine.calculate(
      DateTime.utc(2026, 6, 21),
      city: const PanchangCity(
        id: 'tromso',
        label: 'Tromsø',
        latitude: 69.6492,
        longitude: 18.9553,
        timeZoneId: 'Europe/Oslo',
      ),
    );
    expect(day.sunriseUtc, isNull);
    expect(day.rahukala, isNull);
    expect(day.abhijit, isNull);
    expect(day.brahmaMuhurta, isNull);
    expect(day.choghadiya, isEmpty);
    expect(day.observances, isEmpty);
  });
  test('summer sunset after midnight belongs to the sunrise solar day', () {
    const city = PanchangCity(
      id: 'rovaniemi',
      label: 'Rovaniemi',
      latitude: 66.5039,
      longitude: 25.7294,
      timeZoneId: 'Europe/Helsinki',
    );
    final day = engine.calculate(DateTime.utc(2027, 6, 1), city: city);
    expect(day.sunriseUtc, isNotNull);
    expect(day.sunsetUtc!.isAfter(day.sunriseUtc!), isTrue);
    expect(day.rahukala, isNotNull);
    expect(day.lagna, isEmpty); // Non-monotonic ascendants above polar circle.
  });
  test('date-line and fractional DST zones retain the selected civil date', () {
    const apia = PanchangCity(
      id: 'apia',
      label: 'Apia',
      latitude: -13.8333,
      longitude: -171.75,
      timeZoneId: 'Pacific/Apia',
    );
    final day = engine.calculate(DateTime.utc(2027, 1, 1), city: apia);
    expect(apia.wallClock(day.sunriseUtc!).day, 1);
    const lordHowe = PanchangCity(
      id: 'lh',
      label: 'Lord Howe',
      latitude: -31.55,
      longitude: 159.08,
      timeZoneId: 'Australia/Lord_Howe',
    );
    final date = DateTime.utc(2027, 4, 4);
    expect(
      engine
          .endFor(date, city: lordHowe)
          .difference(engine.startFor(date, city: lordHowe))
          .inMinutes,
      1470,
    );
  });
}
