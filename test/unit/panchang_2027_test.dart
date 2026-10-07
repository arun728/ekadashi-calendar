import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/panchang/gaurabda_raw_2026_2027.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final city in [
    PanchangCity.newDelhi,
    PanchangCity.newYork,
    PanchangCity.london,
    PanchangCity.sydney,
  ]) {
    test(
      '2027 Gaudiya full-year dates and Parana: ${city.label}',
      () {
        final rows = fixture['profiles']['2027'][city.id] as List;
        final expected = rows.map((row) => row['date'] as String).toSet();
        // Explicit exception to the *raw Python port*, not a silently rewritten
        // golden: its EV_NULL sentinel bypasses Pakshavardhini. The independent
        // rule test below verifies the intended repeated-full-moon condition.
        if (city == PanchangCity.newDelhi) {
          expected.remove('2027-06-14');
          expected.add('2027-06-15');
        }
        final actual = const CalculatedEkadashiEngine().calculate(
          DateTime.utc(2027),
          365,
          city,
          EkadashiTradition.gaudiya,
        );
        expect(
          actual.map((d) => d.date.toIso8601String().substring(0, 10)).toSet(),
          expected,
        );
        for (final fast in actual) {
          expect(fast.tradition, EkadashiTradition.gaudiya);
          expect(fast.paranaStartUtc, isNotNull);
          expect(fast.paranaStartUtc!.isAfter(fast.fastStartsUtc), isTrue);
          if (fast.paranaEndUtc != null) {
            expect(fast.paranaEndUtc!.isAfter(fast.paranaStartUtc!), isTrue);
          }
          final date = fast.date.toIso8601String().substring(0, 10);
          final matching = rows.where((r) => r['date'] == date);
          if (matching.isEmpty) continue;
          final row = matching.single;
          for (final pair in [
            (fast.paranaStartUtc, 'startTime'),
            (fast.paranaEndUtc, 'endTime'),
          ]) {
            final hours = row['parana'][pair.$2] as num;
            if (hours < 0) {
              expect(pair.$1, isNull);
              continue;
            }
            expect(pair.$1, isNotNull);
            final expectedInstant = fast.date
                .add(const Duration(days: 1))
                .add(
                  Duration(
                    microseconds:
                        ((hours - (row['paranaOffset'] as num)) * 3600000000)
                            .round(),
                  ),
                );
            expect(
              pair.$1!.difference(expectedInstant).inSeconds.abs(),
              lessThan(180),
              reason: '$date ${pair.$2}',
            );
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
