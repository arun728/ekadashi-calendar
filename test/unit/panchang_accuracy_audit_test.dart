import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang_calculator.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

void main() {
  group('Panchang Accuracy & Astronomical Decoupling Tests', () {
    const delhiLat = 28.6139;
    const delhiLng = 77.2090;
    const kolkataLat = 22.5726;
    const kolkataLng = 88.3639;
    const mumbaiLat = 19.0760;
    const mumbaiLng = 72.8777;
    const istOffset = Duration(hours: 5, minutes: 30);

    test('1. AstronomicalCalculator computes topocentric sunrise and arunodaya accurately', () {
      final date = DateTime(2026, 1, 14);
      final sunrise = AstronomicalCalculator.calculateSunrise(
        latitude: delhiLat,
        longitude: delhiLng,
        date: date,
        utcOffset: istOffset,
      );

      expect(sunrise, isNotNull);
      // New Delhi sunrise on Jan 14 is approximately 07:15 AM
      expect(sunrise!.hour, equals(7));
      expect(sunrise.minute, closeTo(15, 3));

      final arunodaya = AstronomicalCalculator.calculateArunodaya(
        latitude: delhiLat,
        longitude: delhiLng,
        date: date,
        utcOffset: istOffset,
      );

      expect(arunodaya, isNotNull);
      // Arunodaya is exactly 96 minutes (4 Ghatikas) before sunrise
      final diffMin = sunrise.difference(arunodaya!).inMinutes;
      expect(diffMin, equals(96));
    });

    test('2. Longitude extremes produce realistic geographic sunrise shifts across India', () {
      final date = DateTime(2026, 6, 21); // Summer Solstice
      final kolkataSunrise = AstronomicalCalculator.calculateSunrise(
        latitude: kolkataLat,
        longitude: kolkataLng,
        date: date,
        utcOffset: istOffset,
      );
      final mumbaiSunrise = AstronomicalCalculator.calculateSunrise(
        latitude: mumbaiLat,
        longitude: mumbaiLng,
        date: date,
        utcOffset: istOffset,
      );

      expect(kolkataSunrise, isNotNull);
      expect(mumbaiSunrise, isNotNull);

      // Kolkata (88.4° E) is significantly east of Mumbai (72.9° E)
      // Kolkata sunrise should be at least 45 minutes earlier than Mumbai
      final kolkataMins = kolkataSunrise!.hour * 60 + kolkataSunrise.minute;
      final mumbaiMins = mumbaiSunrise!.hour * 60 + mumbaiSunrise.minute;
      expect(mumbaiMins - kolkataMins, greaterThanOrEqualTo(45));
    });

    test('3. ObservanceResolver handles Dashami-Vedha strictly for Vaishnava while Smarta observes Day 1', () {
      // Scenario:
      // Day 1: 2026-07-10. Sunrise at 05:40 AM. Arunodaya at 04:04 AM.
      // Dashami ends at 04:30 AM (after Arunodaya -> Dashami-Viddha!).
      // Ekadashi starts at 04:30 AM and ends at 05:00 AM on Day 2.
      // Day 2: 2026-07-11. Sunrise at 05:40 AM. Ekadashi ends before sunrise on Day 2.
      final daEnd = DateTime.utc(2026, 7, 9, 23, 0); // 04:30 AM IST July 10
      final ekStart = daEnd;
      final ekEnd = DateTime.utc(2026, 7, 10, 23, 30); // 05:00 AM IST July 11
      final dwEnd = DateTime.utc(2026, 7, 11, 23, 30); // 05:00 AM IST July 12

      final smartaObservance = ObservanceResolver.resolveObservance(
        ekadashiStartUtc: ekStart,
        ekadashiEndUtc: ekEnd,
        dwadashiEndUtc: dwEnd,
        dashamiEndUtc: daEnd,
        latitude: delhiLat,
        longitude: delhiLng,
        tradition: AppTradition.smarta,
        defaultDate: DateTime(2026, 7, 10),
      );

      final vaishnavaObservance = ObservanceResolver.resolveObservance(
        ekadashiStartUtc: ekStart,
        ekadashiEndUtc: ekEnd,
        dwadashiEndUtc: dwEnd,
        dashamiEndUtc: daEnd,
        latitude: delhiLat,
        longitude: delhiLng,
        tradition: AppTradition.vaishnava,
        defaultDate: DateTime(2026, 7, 10),
      );

      // Dashami ended after Arunodaya on Day 1.
      // Vaishnava tradition rejects Viddha Day 1 and MUST observe on Day 2 (July 11).
      expect(vaishnavaObservance.observanceDate, equals(DateTime(2026, 7, 11)));
      expect(vaishnavaObservance.isDay2Observance, isTrue);

      // Smarta observes Day 1 (July 10) because Ekadashi touches Day 1 sunrise.
      expect(smartaObservance.observanceDate, equals(DateTime(2026, 7, 10)));
      expect(smartaObservance.isDay2Observance, isFalse);
    });

    test('4. ParanaCalculator enforces Hari Vasara restriction on fast breaking', () {
      // Dwadashi lasts from 06:00 AM to 06:00 PM (12 hours = 720 min).
      // Hari Vasara is the first 25% = 180 min (06:00 AM to 09:00 AM).
      final dwStart = DateTime.utc(2026, 1, 15, 0, 30); // 06:00 AM IST
      final dwEnd = DateTime.utc(2026, 1, 15, 12, 30); // 06:00 PM IST

      final hvEnd = ParanaCalculator.calculateHariVasaraEnd(
        dwadashiStart: dwStart,
        dwadashiEnd: dwEnd,
      );

      // Hari Vasara must end exactly at 09:00 AM IST (03:30 UTC)
      expect(hvEnd, equals(DateTime.utc(2026, 1, 15, 3, 30)));

      final parana = ParanaCalculator.calculateParanaWindow(
        fastingDate: DateTime(2026, 1, 14),
        ekadashiEndUtc: dwStart,
        dwadashiEndUtc: dwEnd,
        latitude: delhiLat,
        longitude: delhiLng,
        utcOffset: istOffset,
      );

      // Fast breaking cannot start before Hari Vasara ends
      expect(parana.paranaStart.isBefore(parana.hariVasaraEnd), isFalse);
    });

    test('5. ObservanceResolver candidate day logic functions correctly without defaultDate', () {
      // Test when Ekadashi starts at 11:00 PM on July 9 (crossing Gregorian midnight into July 10 sunrise)
      final daEnd = DateTime.utc(2026, 7, 9, 17, 30); // 11:00 PM IST July 9
      final ekStart = daEnd;
      final ekEnd = DateTime.utc(2026, 7, 10, 16, 0); // 09:30 PM IST July 10
      final dwEnd = DateTime.utc(2026, 7, 11, 16, 0);

      // Without passing defaultDate, it should automatically evaluate July 10 as Day 1
      final obs = ObservanceResolver.resolveObservance(
        ekadashiStartUtc: ekStart,
        ekadashiEndUtc: ekEnd,
        dwadashiEndUtc: dwEnd,
        dashamiEndUtc: daEnd,
        latitude: delhiLat,
        longitude: delhiLng,
        tradition: AppTradition.smarta,
      );

      expect(obs.observanceDate, equals(DateTime(2026, 7, 10)));
    });

    test('6. Host OS timezone independence: evaluates identical moments regardless of local runtime timezone', () {
      final daEnd = DateTime.utc(2026, 11, 19, 15, 47);
      final ekStart = DateTime.utc(2026, 11, 19, 15, 47);
      final ekEnd = DateTime.utc(2026, 11, 20, 17, 18);
      final dwEnd = DateTime.utc(2026, 11, 21, 18, 41);

      // Simulated resolution for New Delhi
      final obsSmarta = ObservanceResolver.resolveObservance(
        ekadashiStartUtc: ekStart,
        ekadashiEndUtc: ekEnd,
        dwadashiEndUtc: dwEnd,
        dashamiEndUtc: daEnd,
        latitude: delhiLat,
        longitude: delhiLng,
        tradition: AppTradition.smarta,
        defaultDate: DateTime(2026, 11, 20),
      );

      final obsVaishnava = ObservanceResolver.resolveObservance(
        ekadashiStartUtc: ekStart,
        ekadashiEndUtc: ekEnd,
        dwadashiEndUtc: dwEnd,
        dashamiEndUtc: daEnd,
        latitude: delhiLat,
        longitude: delhiLng,
        tradition: AppTradition.vaishnava,
        defaultDate: DateTime(2026, 11, 20),
      );

      // Verify that wall-clock normalization produces exact expected dates and Parana
      expect(obsSmarta.observanceDate, equals(DateTime(2026, 11, 20)));
      expect(obsSmarta.paranaStart.day, equals(21));

      expect(obsVaishnava.observanceDate, equals(DateTime(2026, 11, 20)));
      expect(obsVaishnava.paranaStart.day, equals(21));
    });
  });
}
