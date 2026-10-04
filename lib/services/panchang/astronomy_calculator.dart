import 'dart:math' as math;

/// Deterministic Meeus/NOAA-style solar and lunar calculations used by the
/// Panchang engine. Angles returned to callers are in degrees.
class AstronomyCalculator {
  const AstronomyCalculator._();

  static const double _rad = math.pi / 180;
  static const double _deg = 180 / math.pi;
  static const double _j2000 = 2451545.0;

  static double julianDay(DateTime instant) =>
      instant.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;

  static DateTime fromJulianDay(double jd) =>
      DateTime.fromMillisecondsSinceEpoch(
        ((jd - 2440587.5) * 86400000).round(),
        isUtc: true,
      );

  static double normalize(double angle) => (angle % 360 + 360) % 360;

  static double signedAngle(double angle) {
    final value = normalize(angle);
    return value > 180 ? value - 360 : value;
  }

  static double sunLongitude(DateTime instant) {
    final t = (julianDay(instant) - _j2000) / 36525;
    final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
    final m = normalize(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
    final c =
        (1.914602 - 0.004817 * t - 0.000014 * t * t) * _sin(m) +
        (0.019993 - 0.000101 * t) * _sin(2 * m) +
        0.000289 * _sin(3 * m);
    final omega = 125.04 - 1934.136 * t;
    // Apparent longitude includes the leading nutation and aberration terms.
    return normalize(l0 + c - 0.00569 - 0.00478 * _sin(omega));
  }

  static double moonLongitude(DateTime instant) =>
      normalize(_moonPosition(instant).longitude);

  static double moonLatitude(DateTime instant) =>
      _moonPosition(instant).latitude;

  static double moonDistanceKm(DateTime instant) =>
      _moonPosition(instant).distanceKm;

  static double lahiriAyanamsa(DateTime instant) {
    final years = (julianDay(instant) - _j2000) / 365.2422;
    // Lahiri value at J2000 and the IAU precession rate. It is intentionally
    // isolated so a reviewed sidereal model can replace it without changing
    // the astronomical or observance layers.
    return 23.85675 + years * (50.290966 / 3600);
  }

  static ({double rightAscension, double declination}) sunEquatorial(
    DateTime instant,
  ) {
    final t = (julianDay(instant) - _j2000) / 36525;
    final lambda = sunLongitude(instant) * _rad;
    final omega = (125.04 - 1934.136 * t) * _rad;
    final epsilon =
        (23.439291 - 0.0130042 * t + 0.00256 * math.cos(omega)) * _rad;
    final ra = math.atan2(
      math.cos(epsilon) * math.sin(lambda),
      math.cos(lambda),
    );
    final dec = math.asin(math.sin(epsilon) * math.sin(lambda));
    return (rightAscension: _normalizeRadians(ra), declination: dec);
  }

  static ({double rightAscension, double declination}) moonEquatorial(
    DateTime instant,
  ) {
    final position = _moonPosition(instant);
    final t = (julianDay(instant) - _j2000) / 36525;
    final omega = (125.04 - 1934.136 * t) * _rad;
    final epsilon =
        (23.439291 - 0.0130042 * t + 0.00256 * math.cos(omega)) * _rad;
    final lon = position.longitude * _rad;
    final lat = position.latitude * _rad;
    final x = math.cos(lat) * math.cos(lon);
    final y =
        math.cos(lat) * math.sin(lon) * math.cos(epsilon) -
        math.sin(lat) * math.sin(epsilon);
    final z =
        math.cos(lat) * math.sin(lon) * math.sin(epsilon) +
        math.sin(lat) * math.cos(epsilon);
    return (
      rightAscension: _normalizeRadians(math.atan2(y, x)),
      declination: math.asin(z),
    );
  }

  static double siderealDegrees(DateTime instant) {
    final jd = julianDay(instant);
    final t = (jd - _j2000) / 36525;
    return normalize(
      280.46061837 +
          360.98564736629 * (jd - _j2000) +
          0.000387933 * t * t -
          t * t * t / 38710000,
    );
  }

  static double altitudeDegrees({
    required DateTime instant,
    required double latitude,
    required double longitude,
    required bool moon,
  }) {
    final equatorial = moon ? moonEquatorial(instant) : sunEquatorial(instant);
    final hourAngle =
        signedAngle(
          siderealDegrees(instant) +
              longitude -
              equatorial.rightAscension * _deg,
        ) *
        _rad;
    final lat = latitude * _rad;
    final sinAltitude =
        math.sin(lat) * math.sin(equatorial.declination) +
        math.cos(lat) * math.cos(equatorial.declination) * math.cos(hourAngle);
    var altitude = math.asin(sinAltitude.clamp(-1.0, 1.0)) * _deg;
    if (moon) {
      final horizontalParallax = math.asin(6378.14 / moonDistanceKm(instant));
      final apparentParallax = math.asin(
        math.cos(altitude * _rad) * math.sin(horizontalParallax),
      );
      altitude -= apparentParallax * _deg;
    }
    return altitude;
  }

  static ({double longitude, double latitude, double distanceKm}) _moonPosition(
    DateTime instant,
  ) {
    final jd = julianDay(instant);
    final t = (jd - _j2000) / 36525;
    final lPrime = normalize(
      218.3164477 +
          481267.88123421 * t -
          0.0015786 * t * t +
          t * t * t / 538841 -
          t * t * t * t / 65194000,
    );
    final d = normalize(
      297.8501921 +
          445267.1114034 * t -
          0.0018819 * t * t +
          t * t * t / 545868 -
          t * t * t * t / 113065000,
    );
    final m = normalize(
      357.5291092 +
          35999.0502909 * t -
          0.0001535 * t * t +
          t * t * t / 24490000,
    );
    final mPrime = normalize(
      134.9633964 +
          477198.8675055 * t +
          0.0087414 * t * t +
          t * t * t / 69699 -
          t * t * t * t / 14712000,
    );
    final f = normalize(
      93.272095 +
          483202.0175233 * t -
          0.0036539 * t * t -
          t * t * t / 3526000 +
          t * t * t * t / 863310000,
    );
    final a1 = 119.75 + 131.849 * t;
    final a2 = 53.09 + 479264.29 * t;
    final a3 = 313.45 + 481266.484 * t;
    final e = 1 - 0.002516 * t - 0.0000074 * t * t;
    final e2 = e * e;
    var sumLongitude =
        3958 * _sin(a1) + 1962 * _sin(lPrime - f) + 318 * _sin(a2);
    var sumDistance = 0.0;
    var sumLatitude =
        -2235 * _sin(lPrime) +
        382 * _sin(a3) +
        175 * _sin(a1 - f) +
        175 * _sin(a1 + f) +
        127 * _sin(lPrime - mPrime) -
        115 * _sin(lPrime + mPrime);

    for (final row in _longitudeDistanceTerms) {
      final argument = d * row[0] + m * row[1] + mPrime * row[2] + f * row[3];
      final factor = row[1].abs() == 0 ? 1 : (row[1].abs() == 1 ? e : e2);
      sumLongitude += row[4] * _sin(argument) * factor;
      sumDistance += row[5] * _cos(argument) * factor;
    }
    for (final row in _latitudeTerms) {
      final argument = d * row[0] + m * row[1] + mPrime * row[2] + f * row[3];
      final factor = row[1].abs() == 0 ? 1 : (row[1].abs() == 1 ? e : e2);
      sumLatitude += row[4] * _sin(argument) * factor;
    }

    final nutationArcSeconds =
        -17.20 * _sin(125.04 - 1934.136 * t) -
        1.32 * _sin(2 * (280.4665 + 36000.7698 * t)) -
        0.23 * _sin(2 * lPrime) +
        0.21 * _sin(2 * (125.04 - 1934.136 * t));
    return (
      longitude: normalize(
        lPrime + sumLongitude / 1000000 + nutationArcSeconds / 3600,
      ),
      latitude: sumLatitude / 1000000,
      distanceKm: 385000.56 + sumDistance / 1000,
    );
  }

  static double _normalizeRadians(double radians) =>
      (radians % (math.pi * 2) + math.pi * 2) % (math.pi * 2);
  static double _sin(double degrees) => math.sin(normalize(degrees) * _rad);
  static double _cos(double degrees) => math.cos(normalize(degrees) * _rad);

  // Meeus, Astronomical Algorithms, 2nd ed., tables 47.A and 47.B.
  // Rows are D, M, M', F, longitude coefficient, distance coefficient.
  static const _longitudeDistanceTerms = <List<double>>[
    [0, 0, 1, 0, 6288774, -20905355],
    [2, 0, -1, 0, 1274027, -3699111],
    [2, 0, 0, 0, 658314, -2955968],
    [0, 0, 2, 0, 213618, -569925],
    [0, 1, 0, 0, -185116, 48888],
    [0, 0, 0, 2, -114332, -3149],
    [2, 0, -2, 0, 58793, 246158],
    [2, -1, -1, 0, 57066, -152138],
    [2, 0, 1, 0, 53322, -170733],
    [2, -1, 0, 0, 45758, -204586],
    [0, 1, -1, 0, -40923, -129620],
    [1, 0, 0, 0, -34720, 108743],
    [0, 1, 1, 0, -30383, 104755],
    [2, 0, 0, -2, 15327, 10321],
    [0, 0, 1, 2, -12528, 0],
    [0, 0, 1, -2, 10980, 79661],
    [4, 0, -1, 0, 10675, -34782],
    [0, 0, 3, 0, 10034, -23210],
    [4, 0, -2, 0, 8548, -21636],
    [2, 1, -1, 0, -7888, 24208],
    [2, 1, 0, 0, -6766, 30824],
    [1, 0, -1, 0, -5163, -8379],
    [1, 1, 0, 0, 4987, -16675],
    [2, -1, 1, 0, 4036, -12831],
    [2, 0, 2, 0, 3994, -10445],
    [4, 0, 0, 0, 3861, -11650],
    [2, 0, -3, 0, 3665, 14403],
    [0, 1, -2, 0, -2689, -7003],
    [2, 0, -1, 2, -2602, 0],
    [2, -1, -2, 0, 2390, 10056],
    [1, 0, 1, 0, -2348, 6322],
    [2, -2, 0, 0, 2236, -9884],
    [0, 1, 2, 0, -2120, 5751],
    [0, 2, 0, 0, -2069, 0],
    [2, -2, -1, 0, 2048, -4950],
    [2, 0, 1, -2, -1773, 4130],
    [2, 0, 0, 2, -1595, 0],
    [4, -1, -1, 0, 1215, -3958],
    [0, 0, 2, 2, -1110, 0],
    [3, 0, -1, 0, -892, 3258],
    [2, 1, 1, 0, -810, 2616],
    [4, -1, -2, 0, 759, -1897],
    [0, 2, -1, 0, -713, -2117],
    [2, 2, -1, 0, -700, 2354],
    [2, 1, -2, 0, 691, 0],
    [2, -1, 0, -2, 596, 0],
    [4, 0, 1, 0, 549, -1423],
    [0, 0, 4, 0, 537, -1117],
    [4, -1, 0, 0, 520, -1571],
    [1, 0, -2, 0, -487, -1739],
    [2, 1, 0, -2, -399, 0],
    [0, 0, 2, -2, -381, -4421],
    [1, 1, 1, 0, 351, 0],
    [3, 0, -2, 0, -340, 0],
    [4, 0, -3, 0, 330, 0],
    [2, -1, 2, 0, 327, 0],
    [0, 2, 1, 0, -323, 1165],
    [1, 1, -1, 0, 299, 0],
    [2, 0, 3, 0, 294, 0],
    [2, 0, -1, -2, 0, 8752],
  ];

  // Rows are D, M, M', F and latitude coefficient.
  static const _latitudeTerms = <List<double>>[
    [0, 0, 0, 1, 5128122],
    [0, 0, 1, 1, 280602],
    [0, 0, 1, -1, 277693],
    [2, 0, 0, -1, 173237],
    [2, 0, -1, 1, 55413],
    [2, 0, -1, -1, 46271],
    [2, 0, 0, 1, 32573],
    [0, 0, 2, 1, 17198],
    [2, 0, 1, -1, 9266],
    [0, 0, 2, -1, 8822],
    [2, -1, 0, -1, 8216],
    [2, 0, -2, -1, 4324],
    [2, 0, 1, 1, 4200],
    [2, 1, 0, -1, -3359],
    [2, -1, -1, 1, 2463],
    [2, -1, 0, 1, 2211],
    [2, -1, -1, -1, 2065],
    [0, 1, -1, -1, -1870],
    [4, 0, -1, -1, 1828],
    [0, 1, 0, 1, -1794],
    [0, 0, 0, 3, -1749],
    [0, 1, -1, 1, -1565],
    [1, 0, 0, 1, -1491],
    [0, 1, 1, 1, -1475],
    [0, 1, 1, -1, -1410],
    [0, 1, 0, -1, -1344],
    [1, 0, 0, -1, -1335],
    [0, 0, 3, 1, 1107],
    [4, 0, 0, -1, 1021],
    [4, 0, -1, 1, 833],
    [0, 0, 1, -3, 777],
    [4, 0, -2, 1, 671],
    [2, 0, 0, -3, 607],
    [2, 0, 2, -1, 596],
    [2, -1, 1, -1, 491],
    [2, 0, -2, 1, -451],
    [0, 0, 3, -1, 439],
    [2, 0, 2, 1, 422],
    [2, 0, -3, -1, 421],
    [2, 1, -1, 1, -366],
    [2, 1, 0, 1, -351],
    [4, 0, 0, 1, 331],
    [2, -1, 1, 1, 315],
    [2, -2, 0, -1, 302],
    [0, 0, 1, 3, -283],
    [2, 1, 1, -1, -229],
    [1, 1, 0, -1, 223],
    [1, 1, 0, 1, 223],
    [0, 1, -2, -1, -220],
    [2, 1, -1, -1, -220],
    [1, 0, 1, 1, -185],
    [2, -1, -2, -1, 181],
    [0, 1, 2, 1, -177],
    [4, 0, -2, -1, 176],
    [4, -1, -1, -1, 166],
    [1, 0, 1, -1, -164],
    [4, 0, 1, -1, 132],
    [1, 0, -1, -1, -119],
    [4, -1, 0, -1, 115],
    [2, -2, 0, 1, 107],
  ];
}
