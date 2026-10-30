import 'package:ekadashi_calendar/services/panchang/astronomy_calculator.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tithi, nakshatra, yoga, karana and rashi ends come from a bracketed root
/// search on the (always increasing) angle instead of a 10-minute scan: the
/// same instants with far fewer Sun and Moon evaluations
/// (BoundarySearchTests.swift). Near a boundary the angles change in steps of
/// about a millisecond, so both searches agree to 10 ms, not exactly.
void main() {
  const engine = PanchangEngine();

  /// The scan the engine used before October 2026, kept as the reference.
  DateTime? scanNext(
    DateTime start,
    double startAngle,
    double width,
    double Function(DateTime) angleAt,
  ) {
    final distance =
        width - (startAngle - (startAngle / width).floor() * width);
    final limit = start.add(Duration(hours: width >= 30 ? 35 * 24 : 40));
    var low = start;
    DateTime? high;
    for (
      var probe = start.add(const Duration(minutes: 10));
      !probe.isAfter(limit);
      probe = probe.add(const Duration(minutes: 10))
    ) {
      if (AstronomyCalculator.normalize(angleAt(probe) - startAngle) >=
          distance) {
        high = probe;
        break;
      }
      low = probe;
    }
    if (high == null) return null;
    var right = high;
    for (var i = 0; i < 22; i++) {
      final middle = low.add(right.difference(low) ~/ 2);
      if (AstronomyCalculator.normalize(angleAt(middle) - startAngle) >=
          distance) {
        right = middle;
      } else {
        low = middle;
      }
    }
    return right;
  }

  DateTime scanPrevious(
    DateTime instant,
    double width,
    double Function(DateTime) angleAt,
  ) {
    final index = (angleAt(instant) / width).floor();
    var right = instant;
    for (var i = 1; i <= 48; i++) {
      var left = instant.subtract(Duration(hours: i));
      if ((angleAt(left) / width).floor() == index) continue;
      for (var k = 0; k < 24; k++) {
        final middle = left.add(right.difference(left) ~/ 2);
        if ((angleAt(middle) / width).floor() == index) {
          right = middle;
        } else {
          left = middle;
        }
      }
      return right;
    }
    return instant.subtract(const Duration(hours: 48));
  }

  final angles = <(String, double, double Function(DateTime))>[
    ('tithi', 12, engine.elongation),
    ('karana', 6, engine.elongation),
    ('nakshatra', 40 / 3, engine.siderealMoon),
    ('yoga', 40 / 3, engine.yogaAngle),
    ('sun sign', 30, engine.siderealSun),
    ('moon sign', 30, engine.siderealMoon),
  ];
  final samples = [
    for (final year in const [1900, 1950, 2026, 2027, 2100])
      for (var k = 0; k < 12; k++)
        DateTime.utc(year, 1 + k, 1 + (k * 7) % 27, (k * 5) % 24, k * 4),
  ];
  double apart(DateTime? a, DateTime? b) => a == null || b == null
      ? double.infinity
      : a.difference(b).inMicroseconds.abs() / 1e6;

  test('next boundary matches the scan', () {
    for (final (name, width, angleAt) in angles) {
      for (final start in samples) {
        if (name == 'sun sign' && !start.isBefore(DateTime.utc(2100, 6))) {
          continue;
        }
        final angle = angleAt(start);
        expect(
          apart(
            engine.nextBoundary(start, angle, width, angleAt),
            scanNext(start, angle, width, angleAt),
          ),
          lessThan(0.01),
          reason: '$name $start',
        );
      }
    }
  });

  test('previous boundary matches the scan', () {
    for (final (name, width, angleAt) in angles) {
      if (width >= 30) continue;
      for (final instant in samples) {
        expect(
          apart(
            engine.previousBoundary(instant, width, angleAt),
            scanPrevious(instant, width, angleAt),
          ),
          lessThan(0.01),
          reason: '$name $instant',
        );
      }
    }
  });

  test('boundaries need few evaluations', () {
    var calls = 0;
    double counted(DateTime t) {
      calls++;
      return engine.elongation(t);
    }

    var total = 0;
    for (final start in samples) {
      calls = 0;
      engine.nextBoundary(start, counted(start), 12, counted);
      total += calls;
      calls = 0;
      engine.previousBoundary(start, 12, counted);
      total += calls;
    }
    // The 10-minute scan took about 150 evaluations a boundary.
    expect(total / (2 * samples.length), lessThanOrEqualTo(16));
  });
}
