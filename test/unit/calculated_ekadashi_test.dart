import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';

void main() {
  final date = DateTime.utc(2026, 1, 1);
  EkadashiSample sample(
    int day,
    int tithi, {
    int? arunodaya,
    int nakshatra = 1,
    int? sunsetTithi,
  }) => EkadashiSample(
    date: date.add(Duration(days: day)),
    sunrise: date.add(Duration(days: day, hours: 6)),
    sunset: date.add(Duration(days: day, hours: 18)),
    tithi: tithi,
    arunodayaTithi: arunodaya ?? tithi,
    sunsetTithi: sunsetTithi ?? tithi,
    nakshatra: nakshatra,
  );
  test(
    'Smarta sunrise vs Gaudiya Dashami contamination differ intentionally',
    () {
      final days = [
        sample(0, 10),
        sample(1, 11, arunodaya: 10),
        sample(2, 12),
        sample(3, 13),
        sample(4, 14),
      ];
      expect(
        EkadashiRules.select(days, 1, EkadashiTradition.smarta),
        'Sunrise Ekadashi',
      );
      expect(EkadashiRules.select(days, 1, EkadashiTradition.gaudiya), isNull);
      expect(
        EkadashiRules.select(days, 2, EkadashiTradition.gaudiya),
        'Viddha / shifted to Dwadashi',
      );
    },
  );
  test('repeated Ekadashi with extended Dwadashi is the second day', () {
    final days = [
      sample(0, 10),
      sample(1, 11),
      sample(2, 11),
      sample(3, 12),
      sample(4, 13),
    ];
    // Drik: when Dwadashi also reaches the following sunrise, Smarta
    // householders fast on the second day, with Parana in Dwadashi.
    expect(EkadashiRules.select(days, 1, EkadashiTradition.smarta), isNull);
    expect(EkadashiRules.select(days, 2, EkadashiTradition.smarta), isNotNull);
    expect(EkadashiRules.select(days, 1, EkadashiTradition.gaudiya), isNull);
    expect(
      EkadashiRules.select(days, 2, EkadashiTradition.gaudiya),
      'Unmilani',
    );
  });
  test('repeated Ekadashi without extended Dwadashi is the first day', () {
    final days = [
      sample(0, 10),
      sample(1, 11),
      sample(2, 11),
      sample(3, 13),
      sample(4, 14),
    ];
    expect(EkadashiRules.select(days, 1, EkadashiTradition.smarta), isNotNull);
    expect(EkadashiRules.select(days, 2, EkadashiTradition.smarta), isNull);
  });
  test('Smarta skipped Ekadashi or Dwadashi fasts on the Dashami day', () {
    final skippedEkadashi = [
      sample(0, 9),
      sample(1, 10),
      sample(2, 12),
      sample(3, 13),
      sample(4, 14),
    ];
    expect(
      EkadashiRules.select(skippedEkadashi, 1, EkadashiTradition.smarta),
      isNotNull,
    );
    expect(
      EkadashiRules.select(skippedEkadashi, 2, EkadashiTradition.smarta),
      isNull,
    );
    final skippedDwadashi = [
      sample(0, 9),
      sample(1, 10),
      sample(2, 11),
      sample(3, 13),
      sample(4, 14),
    ];
    expect(
      EkadashiRules.select(skippedDwadashi, 1, EkadashiTradition.smarta),
      isNotNull,
    );
    expect(
      EkadashiRules.select(skippedDwadashi, 2, EkadashiTradition.smarta),
      isNull,
    );
  });
  test('Dwadashi kshaya selects Trisprisha; extended Dwadashi Vyanjuli', () {
    final skipped = [
      sample(0, 10),
      sample(1, 11),
      sample(2, 13),
      sample(3, 14),
    ];
    expect(
      EkadashiRules.select(skipped, 1, EkadashiTradition.gaudiya),
      'Trisprisha',
    );
    final extended = [
      sample(0, 10),
      sample(1, 11),
      sample(2, 12),
      sample(3, 12),
      sample(4, 13),
    ];
    expect(
      EkadashiRules.select(extended, 1, EkadashiTradition.gaudiya),
      isNull,
    );
    expect(
      EkadashiRules.select(extended, 2, EkadashiTradition.gaudiya),
      'Vyanjuli',
    );
  });
  test('nakshatra Mahadvadashi is explicit and only in bright fortnight', () {
    final days = [
      sample(0, 10),
      sample(1, 11),
      sample(2, 12, nakshatra: 4),
      sample(3, 13, nakshatra: 4),
      sample(4, 14),
    ];
    expect(EkadashiRules.select(days, 2, EkadashiTradition.gaudiya), 'Jayanti');
    expect(EkadashiRules.select(days, 1, EkadashiTradition.gaudiya), isNull);
  });
  test('missing sunrise never produces a fasting recommendation', () {
    final days = [
      sample(0, 10),
      EkadashiSample(
        date: date,
        sunrise: null,
        sunset: null,
        tithi: 11,
        arunodayaTithi: 11,
        sunsetTithi: 11,
        nakshatra: 1,
      ),
      sample(2, 12),
    ];
    expect(EkadashiRules.select(days, 1, EkadashiTradition.smarta), isNull);
  });
  test(
    'Pakshavardhini is not bypassed when no nakshatra Mahadvadashi matches',
    () {
      final days = [
        sample(0, 10),
        sample(1, 11),
        sample(2, 12),
        sample(3, 13),
        sample(4, 14),
        sample(5, 15),
        sample(6, 15),
        sample(7, 16),
      ];
      expect(EkadashiRules.select(days, 1, EkadashiTradition.gaudiya), isNull);
      expect(
        EkadashiRules.select(days, 2, EkadashiTradition.gaudiya),
        'Pakshavardhini',
      );
    },
  );
}
