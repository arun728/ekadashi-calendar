import 'astronomical_calculator.dart';

/// Output data model for location-specific Parana calculation
class CalculatedParanaWindow {
  final DateTime paranaStart;
  final DateTime paranaEnd;
  final DateTime hariVasaraEnd;
  final DateTime dwadashiEnd;

  const CalculatedParanaWindow({
    required this.paranaStart,
    required this.paranaEnd,
    required this.hariVasaraEnd,
    required this.dwadashiEnd,
  });

  String formatTime(DateTime dt) => AstronomicalCalculator.formatTime(dt);

  String get paranaWindowStr => '${formatTime(paranaStart)} - ${formatTime(paranaEnd)}';

  String toIsoString(DateTime dt, {String offset = '+05:30'}) =>
      AstronomicalCalculator.toIsoString(dt, offset: offset);

  String get paranaStartIso => toIsoString(paranaStart);
  String get paranaEndIso => toIsoString(paranaEnd);
  bool get isShortWindow => paranaEnd.difference(paranaStart).inMinutes < 15;
}

/// Dedicated Engine for Shastric Parana (Fast-Breaking) Resolution
///
/// Implements canonical Dharma Shastra rules:
/// 1. Fast breaking MUST occur during Dwadashi tithi.
/// 2. Fast breaking MUST NOT occur during Hari Vasara (first 1/4th of Dwadashi).
/// 3. If Hari Vasara extends past sunrise, Parana begins only after Hari Vasara ends.
/// 4. If Dwadashi ends early in the morning, Parana must be completed before Dwadashi ends.
/// 5. If Dwadashi ends before sunrise, Parana is performed in the first quarter of the day.
class ParanaCalculator {
  /// Calculate Hari Vasara End moment.
  /// In Hindu Shastras, Hari Vasara is the first 1/4th (25%) of Dwadashi tithi duration.
  static DateTime calculateHariVasaraEnd({
    required DateTime dwadashiStart,
    required DateTime dwadashiEnd,
  }) {
    final duration = dwadashiEnd.difference(dwadashiStart);
    final quarterMillis = (duration.inMilliseconds * 0.25).round();
    return dwadashiStart.add(Duration(milliseconds: quarterMillis));
  }

  /// Calculate canonical Parana (fast-breaking) window for any fasting date and location
  static CalculatedParanaWindow calculateParanaWindow({
    required DateTime fastingDate,
    required DateTime ekadashiEndUtc,
    required DateTime dwadashiEndUtc,
    required double latitude,
    required double longitude,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) {
    final day2 = fastingDate.add(const Duration(days: 1));
    final nextSunrise = AstronomicalCalculator.calculateSunrise(
      latitude: latitude,
      longitude: longitude,
      date: day2,
      utcOffset: utcOffset,
    ) ?? DateTime(day2.year, day2.month, day2.day, 6, 0);

    final localEkadashiEnd = ekadashiEndUtc.add(utcOffset);
    final localDwadashiEnd = dwadashiEndUtc.add(utcOffset);
    final localDwadashiStart = localEkadashiEnd;

    final hariVasaraEnd = calculateHariVasaraEnd(
      dwadashiStart: localDwadashiStart,
      dwadashiEnd: localDwadashiEnd,
    );

    // Normalize wall-clock representations to UTC for timezone-independent comparison
    final cmpNextSunrise = AstronomicalCalculator.toUtcWallClock(nextSunrise);
    final cmpHariVasaraEnd = AstronomicalCalculator.toUtcWallClock(hariVasaraEnd);
    final cmpLocalDwadashiEnd = AstronomicalCalculator.toUtcWallClock(localDwadashiEnd);

    // Parana (fast-breaking) Calculation on the morning after fasting
    DateTime paranaStart;
    if (cmpHariVasaraEnd.isAfter(cmpNextSunrise) && cmpHariVasaraEnd.isBefore(cmpLocalDwadashiEnd)) {
      paranaStart = hariVasaraEnd;
    } else {
      paranaStart = nextSunrise;
    }

    final cmpParanaStart = AstronomicalCalculator.toUtcWallClock(paranaStart);

    DateTime paranaEnd;
    if (cmpLocalDwadashiEnd.isAfter(cmpParanaStart) &&
        cmpLocalDwadashiEnd.isBefore(cmpNextSunrise.add(const Duration(hours: 6)))) {
      // Dwadashi ends during the morning / early afternoon
      paranaEnd = localDwadashiEnd;
    } else {
      // Standard morning parana window (approx 2.5 to 3 hours after sunrise, within 1st quarter of day)
      paranaEnd = nextSunrise.add(const Duration(hours: 2, minutes: 30));
    }

    final cmpParanaEnd = AstronomicalCalculator.toUtcWallClock(paranaEnd);

    // Safety check: Parana end must always be strictly after parana start.
    // If Dwadashi ended before Parana start (e.g. before sunrise or before Hari Vasara end),
    // canonical rule allows breaking fast after sunrise up to the 1st quarter of the day.
    if (!cmpParanaEnd.isAfter(cmpParanaStart)) {
      paranaEnd = paranaStart.add(const Duration(hours: 2, minutes: 30));
    }

    return CalculatedParanaWindow(
      paranaStart: paranaStart,
      paranaEnd: paranaEnd,
      hariVasaraEnd: hariVasaraEnd,
      dwadashiEnd: localDwadashiEnd,
    );
  }
}
