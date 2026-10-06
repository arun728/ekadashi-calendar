import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/astronomy_calculator.dart';

void main() {
  test(
    '2026–2027 longitudes agree with independent Swiss/Moshier fixtures',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/panchang/ephemeris_2026_2027.json',
                ).readAsStringSync(),
              )
              as Map;
      for (final row in fixture['samples'] as List) {
        final date = DateTime.parse(row['utc'] as String);
        double error(double calculated, num reference) =>
            AstronomyCalculator.signedAngle(calculated - reference).abs();
        expect(
          error(AstronomyCalculator.sunLongitude(date), row['sun']),
          lessThan(0.01),
          reason: 'Sun $date',
        );
        expect(
          error(AstronomyCalculator.moonLongitude(date), row['moon']),
          lessThan(0.003),
          reason: 'Moon $date',
        );
      }
    },
  );
  test('ascendant agrees with independent 2027 house-angle fixtures', () {
    final rows =
        jsonDecode(
              File(
                'test/fixtures/panchang/ascendant_2027.json',
              ).readAsStringSync(),
            )
            as List;
    for (final row in rows) {
      final value = AstronomyCalculator.ascendantLongitude(
        DateTime.parse(row['utc']),
        row['latitude'],
        row['longitude'],
      );
      expect(
        AstronomyCalculator.signedAngle(value - row['ascendant']).abs(),
        lessThan(.02),
      );
    }
  });
  test(
    'sidereal Moon uses a consistent equinox at the 2027 Vijaya boundary',
    () {
      final fixture = jsonDecode(
        File(
          'test/fixtures/panchang/ephemeris_2026_2027.json',
        ).readAsStringSync(),
      );
      for (final row in [...fixture['samples'], fixture['boundary_sample']]) {
        final date = DateTime.parse(row['utc']);
        final value = AstronomyCalculator.normalize(
          AstronomyCalculator.moonLongitude(date) -
              AstronomyCalculator.apparentLahiriAyanamsa(date),
        );
        expect(
          AstronomyCalculator.signedAngle(value - row['siderealMoon']).abs(),
          lessThan(.003),
        );
      }
    },
  );
}
