import 'tradition_service.dart';
import 'astronomical_calculator.dart';
import 'parana_calculator.dart';
import 'observance_resolver.dart';

// Re-export models and decoupled components for seamless module imports
export 'astronomical_calculator.dart';
export 'parana_calculator.dart';
export 'observance_resolver.dart';

/// Astronomical Panchang Calculation Facade Service
///
/// Unifies and coordinates the three decoupled Panchang components:
/// 1. [AstronomicalCalculator]: Topocentric solar positioning, sunrise, sunset, and arunodaya.
/// 2. [ObservanceResolver]: Shastric observance rules for Smarta, Vaishnava, and General traditions.
/// 3. [ParanaCalculator]: Canonical fast-breaking windows based on Dwadashi tithi & Hari Vasara.
class PanchangCalculator {
  static const double standardZenith = AstronomicalCalculator.standardZenith;
  static const int arunodayaMinutes = AstronomicalCalculator.arunodayaMinutes;

  /// Calculate precise Sunrise for a given date and location.
  static DateTime? calculateSunrise({
    required double latitude,
    required double longitude,
    required DateTime date,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) =>
      AstronomicalCalculator.calculateSunrise(
        latitude: latitude,
        longitude: longitude,
        date: date,
        utcOffset: utcOffset,
      );

  /// Calculate precise Sunset for a given date and location.
  static DateTime? calculateSunset({
    required double latitude,
    required double longitude,
    required DateTime date,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) =>
      AstronomicalCalculator.calculateSunset(
        latitude: latitude,
        longitude: longitude,
        date: date,
        utcOffset: utcOffset,
      );

  /// Calculate Arunodaya time (96 minutes before sunrise).
  static DateTime? calculateArunodaya({
    required double latitude,
    required double longitude,
    required DateTime date,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) =>
      AstronomicalCalculator.calculateArunodaya(
        latitude: latitude,
        longitude: longitude,
        date: date,
        utcOffset: utcOffset,
      );

  /// Calculate Hari Vasara End moment.
  /// In Hindu Shastras, Hari Vasara is the first 1/4th (25%) of Dwadashi tithi duration.
  static DateTime calculateHariVasaraEnd({
    required DateTime dwadashiStart,
    required DateTime dwadashiEnd,
  }) =>
      ParanaCalculator.calculateHariVasaraEnd(
        dwadashiStart: dwadashiStart,
        dwadashiEnd: dwadashiEnd,
      );

  /// Calculate canonical Parana (fast-breaking) window for any fasting date and location
  static CalculatedParanaWindow calculateParanaWindow({
    required DateTime fastingDate,
    required DateTime ekadashiEndUtc,
    required DateTime dwadashiEndUtc,
    required double latitude,
    required double longitude,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) =>
      ParanaCalculator.calculateParanaWindow(
        fastingDate: fastingDate,
        ekadashiEndUtc: ekadashiEndUtc,
        dwadashiEndUtc: dwadashiEndUtc,
        latitude: latitude,
        longitude: longitude,
        utcOffset: utcOffset,
      );

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
  }) =>
      ObservanceResolver.resolveObservance(
        ekadashiStartUtc: ekadashiStartUtc,
        ekadashiEndUtc: ekadashiEndUtc,
        dwadashiEndUtc: dwadashiEndUtc,
        dashamiEndUtc: dashamiEndUtc,
        latitude: latitude,
        longitude: longitude,
        tradition: tradition,
        utcOffset: utcOffset,
        defaultDate: defaultDate,
      );

  /// Format DateTime to "hh:mm a" string (e.g. "06:30 AM")
  static String formatTime(DateTime dt) => AstronomicalCalculator.formatTime(dt);

  /// Format DateTime to ISO 8601 with timezone offset string
  static String toIsoString(DateTime dt, {String offset = '+05:30'}) =>
      AstronomicalCalculator.toIsoString(dt, offset: offset);
}
