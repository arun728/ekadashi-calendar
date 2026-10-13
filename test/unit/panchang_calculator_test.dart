import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang_calculator.dart';
import 'package:ekadashi_calendar/services/indian_cities_data.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/native_location_service.dart';

void main() {
  group('PanchangCalculator & NOAA Solar Algorithms', () {
    test('Calculates accurate sunrise for major Indian cities on Equinox', () {
      final equinox = DateTime(2026, 3, 20); // Vernal equinox

      // Chennai (13.08 N, 80.27 E)
      final riseChennai = PanchangCalculator.calculateSunrise(
        latitude: 13.0827,
        longitude: 80.2707,
        date: equinox,
      );
      expect(riseChennai, isNotNull);
      expect(riseChennai!.hour, 6);
      expect(riseChennai.minute, inInclusiveRange(10, 20)); // Approx 06:14 AM

      // Kolkata (22.57 N, 88.36 E) - East
      final riseKolkata = PanchangCalculator.calculateSunrise(
        latitude: 22.5726,
        longitude: 88.3639,
        date: equinox,
      );
      expect(riseKolkata, isNotNull);
      expect(riseKolkata!.hour, 5);
      expect(riseKolkata.minute, inInclusiveRange(40, 55)); // Approx 05:44 AM

      // Mumbai (19.08 N, 72.88 E) - West
      final riseMumbai = PanchangCalculator.calculateSunrise(
        latitude: 19.0760,
        longitude: 72.8777,
        date: equinox,
      );
      expect(riseMumbai, isNotNull);
      expect(riseMumbai!.hour, 6);
      expect(riseMumbai.minute, inInclusiveRange(40, 55)); // Approx 06:44 AM

      // Difference between Kolkata (East) and Mumbai (West) should be ~1 hour
      final diffMinutes = riseMumbai.difference(riseKolkata).inMinutes;
      expect(diffMinutes, inInclusiveRange(50, 70));
    });

    test('Arunodaya is exactly 96 minutes (4 ghatikas) before sunrise', () {
      final date = DateTime(2026, 5, 1);
      final sunrise = PanchangCalculator.calculateSunrise(
        latitude: 28.6139,
        longitude: 77.2090,
        date: date,
      );
      final arunodaya = PanchangCalculator.calculateArunodaya(
        latitude: 28.6139,
        longitude: 77.2090,
        date: date,
      );

      expect(sunrise, isNotNull);
      expect(arunodaya, isNotNull);
      expect(sunrise!.difference(arunodaya!).inMinutes, 96);
    });

    test('Hari Vasara is the first 25% of Dwadashi tithi duration', () {
      final dwadashiStart = DateTime.parse('2026-02-14T06:00:00+05:30');
      final dwadashiEnd = DateTime.parse('2026-02-14T12:00:00+05:30');
      final hariVasaraEnd = PanchangCalculator.calculateHariVasaraEnd(
        dwadashiStart: dwadashiStart,
        dwadashiEnd: dwadashiEnd,
      );

      // First 25% of 6 hours (360 mins) is 90 mins -> 07:30
      expect(hariVasaraEnd.difference(dwadashiStart).inMinutes, 90);
    });

    test('ResolveObservance produces valid observance and parana window', () {
      final observance = PanchangCalculator.resolveObservance(
        ekadashiStartUtc: DateTime.parse('2026-02-12T16:00:00Z'),
        ekadashiEndUtc: DateTime.parse('2026-02-13T17:00:00Z'),
        dwadashiEndUtc: DateTime.parse('2026-02-14T18:00:00Z'),
        dashamiEndUtc: DateTime.parse('2026-02-12T15:00:00Z'),
        latitude: 13.0827,
        longitude: 80.2707,
        tradition: AppTradition.smarta,
      );

      expect(observance.observanceDate, isNotNull);
      expect(observance.paranaStart.isAfter(observance.fastingStart), isTrue);
      expect(observance.paranaEnd.isAfter(observance.paranaStart), isTrue);
    });
  });

  group('IndianCitiesData Directory Coverage', () {
    test('Covers all 28 states and 8 union territories (total 36 entities)', () {
      final statesAndUTs = IndianCitiesData.statesAndUTs;
      expect(statesAndUTs.length, 36);

      // Check key states
      expect(statesAndUTs.contains('Tamil Nadu'), isTrue);
      expect(statesAndUTs.contains('Telangana'), isTrue);
      expect(statesAndUTs.contains('Andhra Pradesh'), isTrue);
      expect(statesAndUTs.contains('Uttar Pradesh'), isTrue);
      expect(statesAndUTs.contains('Maharashtra'), isTrue);
      expect(statesAndUTs.contains('Gujarat'), isTrue);
      expect(statesAndUTs.contains('Assam'), isTrue);
      expect(statesAndUTs.contains('West Bengal'), isTrue);
      expect(statesAndUTs.contains('Delhi'), isTrue);
      expect(statesAndUTs.contains('Jammu & Kashmir'), isTrue);
      expect(statesAndUTs.contains('Ladakh'), isTrue);
      expect(statesAndUTs.contains('Andaman & Nicobar Islands'), isTrue);
      expect(statesAndUTs.contains('Lakshadweep'), isTrue);
    });

    test('Find nearest city maps coordinates accurately', () {
      // Near Chennai Marina Beach (13.05, 80.28)
      final nearestChennai = IndianCitiesData.findNearestCity(13.05, 80.28);
      expect(nearestChennai.name, 'Chennai');
      expect(nearestChennai.state, 'Tamil Nadu');

      // Near Mumbai Bandra (19.05, 72.83)
      final nearestMumbai = IndianCitiesData.findNearestCity(19.05, 72.83);
      expect(nearestMumbai.name, 'Mumbai');
      expect(nearestMumbai.state, 'Maharashtra');

      // Near Connaught Place New Delhi (28.63, 77.21)
      final nearestDelhi = IndianCitiesData.findNearestCity(28.63, 77.21);
      expect(nearestDelhi.name, 'New Delhi');
      expect(nearestDelhi.state, 'Delhi');
    });

    test('Search filters cities by query and state correctly', () {
      final tamilCities = IndianCitiesData.getCitiesForState('Tamil Nadu');
      expect(tamilCities.length, greaterThanOrEqualTo(5));

      final searchResults = IndianCitiesData.searchCities('Vara');
      expect(searchResults.any((c) => c.name == 'Varanasi'), isTrue);
    });
  });

  group('Language Independence & Location-Aware Observance Resolution', () {
    final ekadashiService = EkadashiService();

    setUpAll(() {
      final file = File('assets/ekadashi_data.json');
      final data = json.decode(file.readAsStringSync());
      ekadashiService.loadDataFromJson(data);
    });

    test('Same location and tradition yields identical dates in all 4 languages (en, ta, te, hi)', () {
      final chennaiLoc = LocationData(
        latitude: 13.0827,
        longitude: 80.2707,
        city: 'Chennai',
        state: 'Tamil Nadu',
        timezone: 'IST',
      );

      final enDates = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.smarta,
      );

      final taDates = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'ta',
        tradition: AppTradition.smarta,
      );

      final teDates = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'te',
        tradition: AppTradition.smarta,
      );

      final hiDates = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'hi',
        tradition: AppTradition.smarta,
      );

      expect(enDates.length, 49);
      expect(taDates.length, 49);
      expect(teDates.length, 49);
      expect(hiDates.length, 49);

      for (int i = 0; i < 49; i++) {
        expect(taDates[i].date, enDates[i].date,
            reason: 'Tamil date must match English date for event ${enDates[i].id}');
        expect(teDates[i].date, enDates[i].date,
            reason: 'Telugu date must match English date for event ${enDates[i].id}');
        expect(hiDates[i].date, enDates[i].date,
            reason: 'Hindi date must match English date for event ${enDates[i].id}');

        // But names should be translated
        expect(enDates[i].name.isNotEmpty, isTrue);
        expect(taDates[i].name.isNotEmpty, isTrue);
        expect(teDates[i].name.isNotEmpty, isTrue);
        expect(hiDates[i].name.isNotEmpty, isTrue);
      }
    });

    test('Smarta vs Vaishnava dates diverge correctly for tradition-variant events', () {
      final chennaiLoc = LocationData(
        latitude: 13.0827,
        longitude: 80.2707,
        city: 'Chennai',
        state: 'Tamil Nadu',
        timezone: 'IST',
      );

      final smartaEvents = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.smarta,
      );

      final vaishnavaEvents = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.vaishnava,
      );

      // Event #13: Yogini Ekadashi 2026 (Jul 10 Smarta vs Jul 11 Vaishnava)
      final yoginiSmarta = smartaEvents.firstWhere((e) => e.id == 13);
      final yoginiVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 13);
      expect(yoginiSmarta.date, DateTime(2026, 7, 10));
      expect(yoginiVaishnava.date, DateTime(2026, 7, 11));

      // Event #26: Pausha Putrada Ekadashi 2027 (Jan 18 Smarta vs Jan 19 Vaishnava)
      final putradaSmarta = smartaEvents.firstWhere((e) => e.id == 26);
      final putradaVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 26);
      expect(putradaSmarta.date, DateTime(2027, 1, 18));
      expect(putradaVaishnava.date, DateTime(2027, 1, 19));

      // Event #36: Nirjala Ekadashi 2027 (Jun 14 Smarta vs Jun 15 Vaishnava)
      final nirjalaSmarta = smartaEvents.firstWhere((e) => e.id == 36);
      final nirjalaVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 36);
      expect(nirjalaSmarta.date, DateTime(2027, 6, 14));
      expect(nirjalaVaishnava.date, DateTime(2027, 6, 15));
    });
  });
}
