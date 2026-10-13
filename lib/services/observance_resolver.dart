import 'tradition_service.dart';
import 'astronomical_calculator.dart';
import 'parana_calculator.dart';

/// Output data model for location-specific Panchang calculation
class CalculatedEkadashiObservance {
  final DateTime observanceDate;
  final DateTime fastingStart;
  final DateTime paranaStart;
  final DateTime paranaEnd;
  final bool isDay2Observance;
  final AppTradition tradition;
  final DateTime hariVasaraEnd;
  final DateTime dwadashiEnd;

  const CalculatedEkadashiObservance({
    required this.observanceDate,
    required this.fastingStart,
    required this.paranaStart,
    required this.paranaEnd,
    required this.isDay2Observance,
    required this.tradition,
    required this.hariVasaraEnd,
    required this.dwadashiEnd,
  });

  String formatTime(DateTime dt) => AstronomicalCalculator.formatTime(dt);

  String get fastStartTimeStr => formatTime(fastingStart);
  String get paranaWindowStr => '${formatTime(paranaStart)} - ${formatTime(paranaEnd)}';

  String toIsoString(DateTime dt, {String offset = '+05:30'}) =>
      AstronomicalCalculator.toIsoString(dt, offset: offset);

  String get fastingStartIso => toIsoString(fastingStart);
  String get paranaStartIso => toIsoString(paranaStart);
  String get paranaEndIso => toIsoString(paranaEnd);
  String get dateStr =>
      '${observanceDate.year.toString().padLeft(4, '0')}-${observanceDate.month.toString().padLeft(2, '0')}-${observanceDate.day.toString().padLeft(2, '0')}';
  bool get isShortWindow => paranaEnd.difference(paranaStart).inMinutes < 15;
}

/// Dedicated Engine for Shastric Observance Resolution
///
/// Implements traditional Hindu calendar rules:
/// 1. Smarta / General: Dharma Sindhu and Nirnaya Sindhu rules (Shuddha Ekadashi, sunrise contact).
/// 2. Vaishnava: Hari Bhakti Vilasa rules (strict Dashami-Vedha avoidance at Arunodaya, Ekadashi Vridhi on Day 2).
/// 3. Cross-platform instant normalization (operating-system timezone independence).
class ObservanceResolver {
  /// Resolve location-specific observance date and timings for an Ekadashi occurrence.
  static CalculatedEkadashiObservance resolveObservance({
    required DateTime ekadashiStartUtc,
    required DateTime ekadashiEndUtc,
    required DateTime dwadashiEndUtc,
    required DateTime dashamiEndUtc,
    required double latitude,
    required double longitude,
    required AppTradition tradition,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
    DateTime? defaultDate,
  }) {
    final localEkadashiStart = ekadashiStartUtc.add(utcOffset);
    final localEkadashiEnd = ekadashiEndUtc.add(utcOffset);
    final localDashamiEnd = dashamiEndUtc.add(utcOffset);

    // Determine candidate calendar dates around the tithi
    DateTime day1;
    if (defaultDate != null) {
      day1 = DateTime(defaultDate.year, defaultDate.month, defaultDate.day);
    } else {
      // Robust astronomical candidate detection:
      // If Ekadashi starts after sunrise on localEkadashiStart calendar day,
      // the first sunrise touching Ekadashi is on the following day.
      final startCalendarDay = DateTime(
        localEkadashiStart.year,
        localEkadashiStart.month,
        localEkadashiStart.day,
      );
      final srStart = AstronomicalCalculator.calculateSunrise(
        latitude: latitude,
        longitude: longitude,
        date: startCalendarDay,
        utcOffset: utcOffset,
      ) ?? DateTime(startCalendarDay.year, startCalendarDay.month, startCalendarDay.day, 6, 0);

      final cmpLocalEkStart = AstronomicalCalculator.toUtcWallClock(localEkadashiStart);
      final cmpSrStart = AstronomicalCalculator.toUtcWallClock(srStart);

      if (cmpLocalEkStart.isAfter(cmpSrStart) || cmpLocalEkStart.isAtSameMomentAs(cmpSrStart)) {
        day1 = startCalendarDay.add(const Duration(days: 1));
      } else {
        day1 = startCalendarDay;
      }
    }

    final day2 = day1.add(const Duration(days: 1));

    final sunrise1 = AstronomicalCalculator.calculateSunrise(
      latitude: latitude,
      longitude: longitude,
      date: day1,
      utcOffset: utcOffset,
    ) ?? DateTime(day1.year, day1.month, day1.day, 6, 0);
    final arunodaya1 = sunrise1.subtract(const Duration(minutes: AstronomicalCalculator.arunodayaMinutes));

    final sunrise2 = AstronomicalCalculator.calculateSunrise(
      latitude: latitude,
      longitude: longitude,
      date: day2,
      utcOffset: utcOffset,
    ) ?? DateTime(day2.year, day2.month, day2.day, 6, 0);
    final arunodaya2 = sunrise2.subtract(const Duration(minutes: AstronomicalCalculator.arunodayaMinutes));

    // Normalize all dates to UTC wall-clock for cross-platform, timezone-independent comparison
    final cmpSunrise1 = AstronomicalCalculator.toUtcWallClock(sunrise1);
    final cmpArunodaya1 = AstronomicalCalculator.toUtcWallClock(arunodaya1);
    final cmpSunrise2 = AstronomicalCalculator.toUtcWallClock(sunrise2);
    final cmpArunodaya2 = AstronomicalCalculator.toUtcWallClock(arunodaya2);

    final cmpLocalDashamiEnd = AstronomicalCalculator.toUtcWallClock(localDashamiEnd);
    final cmpLocalEkadashiStart = AstronomicalCalculator.toUtcWallClock(localEkadashiStart);
    final cmpLocalEkadashiEnd = AstronomicalCalculator.toUtcWallClock(localEkadashiEnd);

    // Check Shuddha / Viddha conditions
    // Day 1 is Dashami-Viddha if Dashami ended AFTER Arunodaya on Day 1
    final isDay1DashamiViddha = cmpLocalDashamiEnd.isAfter(cmpArunodaya1);

    // Check whether Ekadashi touches Sunrise on Day 1
    final isEkadashiActiveAtSunrise1 = cmpLocalEkadashiStart.isBefore(cmpSunrise1) &&
        cmpLocalEkadashiEnd.isAfter(cmpSunrise1);

    // Check whether Ekadashi touches Sunrise on Day 2
    final isEkadashiActiveAtSunrise2 = cmpLocalEkadashiStart.isBefore(cmpSunrise2) &&
        cmpLocalEkadashiEnd.isAfter(cmpSunrise2);

    final isEkadashiActiveAtArunodaya2 = cmpLocalEkadashiStart.isBefore(cmpArunodaya2) &&
        cmpLocalEkadashiEnd.isAfter(cmpArunodaya2);

    DateTime fastingDate;
    DateTime fastingSunrise;
    bool fastsOnDay2 = false;

    if (tradition == AppTradition.vaishnava) {
      // Vaishnava Rule: Strict Dashami-Vedha avoidance (Hari Bhakti Vilasa)
      // If Dashami touches Arunodaya 1, Day 1 CANNOT be observed -> Fast on Day 2
      // If Ekadashi extends over two sunrises (Vridhi) -> Fast on Day 2
      if (isDay1DashamiViddha || isEkadashiActiveAtSunrise2) {
        fastsOnDay2 = true;
      } else if (!isEkadashiActiveAtSunrise1 && isEkadashiActiveAtSunrise2) {
        fastsOnDay2 = true;
      }
    } else {
      // Smarta / General Rule (Dharma Sindhu / Nirnaya Sindhu)
      // If Ekadashi is present at Arunodaya on Day 1, observe on Day 1 (Shuddha)
      // If Ekadashi starts AFTER sunrise 1, observe on Day 2
      if (!isEkadashiActiveAtSunrise1 && (isEkadashiActiveAtSunrise2 || isEkadashiActiveAtArunodaya2)) {
        fastsOnDay2 = true;
      } else if (isDay1DashamiViddha && isEkadashiActiveAtSunrise2) {
        // Viddha Ekadashi where Ekadashi extends to Day 2 sunrise
        fastsOnDay2 = true;
      }
    }

    if (fastsOnDay2) {
      fastingDate = day2;
      fastingSunrise = sunrise2;
    } else {
      fastingDate = day1;
      fastingSunrise = sunrise1;
    }

    // Calculate Parana window on the morning after fasting using canonical Shastric rules
    final paranaWindow = ParanaCalculator.calculateParanaWindow(
      fastingDate: fastingDate,
      ekadashiEndUtc: ekadashiEndUtc,
      dwadashiEndUtc: dwadashiEndUtc,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
    );

    return CalculatedEkadashiObservance(
      observanceDate: fastingDate,
      fastingStart: fastingSunrise,
      paranaStart: paranaWindow.paranaStart,
      paranaEnd: paranaWindow.paranaEnd,
      isDay2Observance: fastsOnDay2,
      tradition: tradition,
      hariVasaraEnd: paranaWindow.hariVasaraEnd,
      dwadashiEnd: paranaWindow.dwadashiEnd,
    );
  }
}
