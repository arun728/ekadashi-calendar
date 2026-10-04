import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/astronomy_calculator.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';

void main() {
  group('Panchang astronomy', () {
    test('Meeus lunar longitude example is reproduced', () {
      // Meeus, Astronomical Algorithms, 2nd ed., Example 47.a (1992-04-12).
      final longitude = AstronomyCalculator.moonLongitude(
        DateTime.utc(1992, 4, 12),
      );
      expect(longitude, closeTo(133.162655, 0.03));
    });

    test('Panchang day uses IST sunrise and city coordinates', () {
      const engine = PanchangEngine();
      final delhi = engine.calculate(DateTime.utc(2026, 10, 4));
      final mumbai = engine.calculate(
        DateTime.utc(2026, 10, 4),
        city: PanchangCity.mumbai,
      );

      expect(delhi.city, PanchangCity.newDelhi);
      expect(delhi.sunriseUtc, isNotNull);
      expect(delhi.sunsetUtc, isNotNull);
      expect(delhi.sunriseUtc!.isUtc, isTrue);
      expect(delhi.sunriseIst!.hour, inInclusiveRange(5, 7));
      expect(delhi.sunsetIst!.hour, inInclusiveRange(17, 19));
      // USNO RSTT (2026-10-04, 28.6139 N, 77.2090 E, UTC+05:30):
      // sunrise 06:16, sunset 18:04. Atmospheric/horizon conditions vary.
      final sunriseMinutes =
          delhi.sunriseIst!.hour * 60 + delhi.sunriseIst!.minute;
      final sunsetMinutes =
          delhi.sunsetIst!.hour * 60 + delhi.sunsetIst!.minute;
      expect((sunriseMinutes - (6 * 60 + 16)).abs(), lessThan(6));
      expect((sunsetMinutes - (18 * 60 + 4)).abs(), lessThan(6));
      expect(delhi.tithi.name, 'Navami');
      expect(delhi.tithi.paksha, 'Krishna');
      expect(
        delhi.sunriseUtc!.difference(mumbai.sunriseUtc!).inMinutes.abs(),
        greaterThan(5),
      );
    });

    test('limbs are sampled at sunrise and expose their next transition', () {
      final day = const PanchangEngine().calculate(DateTime.utc(2026, 10, 4));

      for (final limb in [day.tithi, day.nakshatra, day.yoga, day.karana]) {
        expect(limb.index, greaterThan(0));
        expect(limb.name, isNotEmpty);
        expect(limb.endsAtUtc, isNotNull);
        expect(limb.endsAtUtc!.isAfter(day.sunriseUtc!), isTrue);
        expect(
          limb.endsAtUtc!.difference(day.sunriseUtc!).inHours,
          lessThan(48),
        );
      }
      expect(day.tithi.paksha, anyOf('Shukla', 'Krishna'));
    });

    test('monthly observances are calculated locally without network data', () {
      final day = const PanchangEngine().calculate(DateTime.utc(2026, 2, 15));
      expect(
        day.observances.map((item) => item.name),
        contains('Maha Shivaratri'),
      );
      expect(
        day.observances.every((item) => item.ruleSource == 'calculated'),
        isTrue,
      );
    });

    test('solar ingress is included on the IST civil date', () {
      final day = const PanchangEngine().calculate(DateTime.utc(2026, 1, 14));
      expect(
        day.observances.map((item) => item.name),
        contains('Makar Sankranti'),
      );
    });

    test(
      'annual observances use their sunrise, midday, night and sunset rules',
      () {
        final vasant = const PanchangEngine().calculate(
          DateTime.utc(2026, 1, 23),
        );
        final holika = const PanchangEngine().calculate(
          DateTime.utc(2026, 3, 2),
        );
        final holi = const PanchangEngine().calculate(DateTime.utc(2026, 3, 4));
        final akshaya = const PanchangEngine().calculate(
          DateTime.utc(2026, 4, 20),
        );
        final guru = const PanchangEngine().calculate(
          DateTime.utc(2026, 7, 29),
        );
        final ganesh = const PanchangEngine().calculate(
          DateTime.utc(2026, 9, 14),
        );
        final vijayadashami = const PanchangEngine().calculate(
          DateTime.utc(2026, 10, 20),
        );
        final deepavali = const PanchangEngine().calculate(
          DateTime.utc(2026, 11, 8),
        );

        expect(
          vasant.observances.map((item) => item.name),
          contains('Vasant Panchami'),
        );
        expect(
          holika.observances.map((item) => item.name),
          contains('Holika Dahan'),
        );
        expect(holi.observances.map((item) => item.name), contains('Holi'));
        expect(
          akshaya.observances.map((item) => item.name),
          contains('Akshaya Tritiya'),
        );
        expect(
          guru.observances.map((item) => item.name),
          contains('Guru Purnima'),
        );
        expect(
          ganesh.observances.map((item) => item.name),
          contains('Ganesh Chaturthi'),
        );
        expect(
          vijayadashami.observances.map((item) => item.name),
          contains('Vijayadashami'),
        );
        expect(
          deepavali.observances.map((item) => item.name),
          contains('Deepavali'),
        );
      },
    );

    test('full-moon limb boundary agrees with the USNO phase fixture', () {
      // USNO 2026 full moon: March 3 at 11:38 UTC = 17:08 IST.
      final day = const PanchangEngine().calculate(DateTime.utc(2026, 3, 3));
      expect(day.tithi.index, 15);
      final end = day.tithi.endsAtUtc!;
      final endIst = end.add(const Duration(hours: 5, minutes: 30));
      final minutes = endIst.hour * 60 + endIst.minute;
      expect((minutes - (17 * 60 + 8)).abs(), lessThanOrEqualTo(2));
    });
  });
}
