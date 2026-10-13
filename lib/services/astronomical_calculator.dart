import 'dart:math' as math;

/// Dedicated Astronomical Engine for Topocentric Solar Phenomena
///
/// Implements high-precision NOAA Solar Positioning Equations for:
/// 1. Topocentric Sunrise and Sunset for any global coordinates
/// 2. Arunodaya moment (4 Ghatikas = 96 minutes before sunrise)
/// 3. Cross-platform, timezone-independent instant and wall-clock normalization
class AstronomicalCalculator {
  static const double standardZenith = 90.8333; // 90° 50' (Refraction 34' + semi-diameter 16')
  static const int arunodayaMinutes = 96; // 4 Ghatikas = 96 minutes before sunrise

  /// Calculate precise Sunrise for a given date and location.
  /// Returns a DateTime in local timezone (or with specified UTC offset).
  static DateTime? calculateSunrise({
    required double latitude,
    required double longitude,
    required DateTime date,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) {
    return _calculateSolarEvent(
      latitude: latitude,
      longitude: longitude,
      date: date,
      isSunrise: true,
      utcOffset: utcOffset,
    );
  }

  /// Calculate precise Sunset for a given date and location.
  static DateTime? calculateSunset({
    required double latitude,
    required double longitude,
    required DateTime date,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) {
    return _calculateSolarEvent(
      latitude: latitude,
      longitude: longitude,
      date: date,
      isSunrise: false,
      utcOffset: utcOffset,
    );
  }

  /// Calculate Arunodaya time (96 minutes before sunrise).
  static DateTime? calculateArunodaya({
    required double latitude,
    required double longitude,
    required DateTime date,
    Duration utcOffset = const Duration(hours: 5, minutes: 30),
  }) {
    final sunrise = calculateSunrise(
      latitude: latitude,
      longitude: longitude,
      date: date,
      utcOffset: utcOffset,
    );
    if (sunrise == null) return null;
    return sunrise.subtract(const Duration(minutes: arunodayaMinutes));
  }

  /// Normalizes any DateTime to a UTC wall-clock representation.
  /// Strips host machine local timezone influence so comparisons operate purely on local clock values.
  static DateTime toUtcWallClock(DateTime dt) {
    return DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
  }

  /// Core NOAA solar calculation algorithm.
  static DateTime? _calculateSolarEvent({
    required double latitude,
    required double longitude,
    required DateTime date,
    required bool isSunrise,
    required Duration utcOffset,
  }) {
    final n = _dayOfYear(date.year, date.month, date.day);
    final lngHour = longitude / 15.0;

    // Approximate time
    final t = isSunrise
        ? n + ((6.0 - lngHour) / 24.0)
        : n + ((18.0 - lngHour) / 24.0);

    // Sun's mean anomaly
    final m = (0.9856 * t) - 3.289;
    final mRad = _degToRad(m);

    // Sun's true longitude
    var l = m + (1.916 * math.sin(mRad)) + (0.020 * math.sin(2 * mRad)) + 282.634;
    l = _normalizeDeg(l);
    final lRad = _degToRad(l);

    // Sun's right ascension
    var ra = _radToDeg(math.atan(0.91764 * math.tan(lRad)));
    ra = _normalizeDeg(ra);

    // Right ascension value needs to be in the same quadrant as L
    final lQuadrant = (l / 90.0).floor() * 90.0;
    final raQuadrant = (ra / 90.0).floor() * 90.0;
    ra = ra + (lQuadrant - raQuadrant);
    ra = ra / 15.0;

    // Sun's declination
    final sinDec = 0.39782 * math.sin(lRad);
    final cosDec = math.cos(math.asin(sinDec));

    // Sun's local hour angle
    final latRad = _degToRad(latitude);
    final cosH = (math.cos(_degToRad(standardZenith)) - (sinDec * math.sin(latRad))) /
        (cosDec * math.cos(latRad));

    if (cosH > 1) return null; // Polar night / sun never rises
    if (cosH < -1) return null; // Midnight sun / sun never sets

    final h = isSunrise
        ? 360.0 - _radToDeg(math.acos(cosH))
        : _radToDeg(math.acos(cosH));
    final hHour = h / 15.0;

    // Local mean time of rising/setting
    final tLocal = hHour + ra - (0.06571 * t) - 6.622;

    // Adjust to UTC
    final ut = (tLocal - lngHour) % 24.0;
    final normalizedUt = ut < 0 ? ut + 24.0 : ut;

    // Convert to local time
    final totalOffsetMinutes = utcOffset.inMinutes;
    final localHours = normalizedUt + (totalOffsetMinutes / 60.0);
    final normalizedLocalHours = (localHours % 24.0 + 24.0) % 24.0;

    final hour = normalizedLocalHours.floor();
    final remainderMinutes = (normalizedLocalHours - hour) * 60.0;
    var minute = remainderMinutes.round();
    var adjustedHour = hour;

    if (minute == 60) {
      adjustedHour = (adjustedHour + 1) % 24;
      minute = 0;
    }

    return DateTime(date.year, date.month, date.day, adjustedHour, minute);
  }

  // Helper math utilities
  static int _dayOfYear(int year, int month, int day) {
    final d = DateTime(year, month, day);
    final d0 = DateTime(year, 1, 1);
    return d.difference(d0).inDays + 1;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);
  static double _normalizeDeg(double deg) {
    var d = deg % 360.0;
    if (d < 0) d += 360.0;
    return d;
  }

  /// Format DateTime to "hh:mm a" string (e.g. "06:30 AM")
  static String formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Format DateTime to ISO 8601 with timezone offset string
  static String toIsoString(DateTime dt, {String offset = '+05:30'}) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min:$s$offset';
  }
}
