import 'dart:math' as math;

import 'ephemeris_series.dart';
import 'lunar_series.dart';

/// Deterministic solar and lunar positions for the Panchang engine.
/// Angles returned to callers are in degrees.
///
/// - Sun: VSOP87D Earth series (Bretagnon & Francou 1988), converted to the
///   FK5 frame, with annual aberration and IAU 1980 nutation (Meeus,
///   *Astronomical Algorithms* 2nd ed., ch. 22, 25 and 32).
/// - Moon: ELP 2000-82B (Chapront-Touze & Chapront), 769 terms, light
///   time, secular terms refitted to JPL DE431, IAU 1980 nutation.
/// - Delta T: yearly observed and predicted values (IERS/USNO, as tabulated
///   by Swiss Ephemeris 2.10), linear between years.
/// - Lahiri: 23°51′25.53″ at J2000 plus IAU 2006 general precession, the
///   Swiss Ephemeris SE_SIDM_LAHIRI definition to better than 0.001″.
/// See docs/PANCHANG_ACCURACY.md for the independent comparison.
class AstronomyCalculator {
  const AstronomyCalculator._();

  static const double _rad = math.pi / 180;
  static const double _deg = 180 / math.pi;
  static const double _j2000 = 2451545.0;
  static const double _arcsec = 1 / 3600;

  /// Refraction at the horizon for the standard atmosphere (1013.25 hPa,
  /// 15 °C), 33.6′: the value Swiss Ephemeris applies in swe_rise_trans.
  static const double horizonRefraction = 0.5599;

  static double julianDay(DateTime instant) =>
      instant.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;

  /// Delta T in seconds for a fractional year.
  static double deltaTSeconds(double year) {
    const first = 1900;
    if (year >= first && year < first + _deltaT.length - 1) {
      final i = (year - first).floor();
      final f = year - first - i;
      return _deltaT[i] + (_deltaT[i + 1] - _deltaT[i]) * f;
    }
    if (year >= first + _deltaT.length - 1) {
      // Continue the last tabulated trend (about +0.29 s per year).
      final last = _deltaT.length - 1;
      return _deltaT[last] +
          (_deltaT[last] - _deltaT[last - 1]) * (year - first - last);
    }
    final u = (year - 1820) / 100;
    return -20 + 32 * u * u;
  }

  /// TT = UT + Delta T. UTC is treated as UT1 (sub-second difference).
  static double terrestrialJulianDay(DateTime instant) {
    final jd = julianDay(instant);
    final year = 2000 + (jd - _j2000) / 365.25;
    return jd + deltaTSeconds(year) / 86400;
  }

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

  // --- Nutation (IAU 1980) -------------------------------------------------

  // Nutation and the Sun change smoothly, so both are evaluated at six-hour
  // nodes and interpolated quadratically (error below 0.0001 arcseconds).
  static const double _nodeStep = 0.25;
  static final Map<int, List<double>> _nodes = {};

  static List<double> _node(int index) {
    final cached = _nodes[index];
    if (cached != null) return cached;
    if (_nodes.length > 4096) _nodes.clear();
    final jd = index * _nodeStep;
    final nutation = _nutationSeries(jd);
    final sun = _sunSeries(jd, nutation.$1);
    return _nodes[index] = [sun.$1, sun.$2, sun.$3, nutation.$1, nutation.$2];
  }

  /// Quadratic interpolation of node component [k]; longitude is unwrapped.
  static double _interpolate(double jdTt, int k) {
    final x = jdTt / _nodeStep;
    final i = x.round();
    final p = x - i;
    var a = _node(i - 1)[k], b = _node(i)[k], c = _node(i + 1)[k];
    if (k == 0) {
      a = b + signedAngle(a - b);
      c = b + signedAngle(c - b);
    }
    return b + p * (c - a) / 2 + p * p * (a - 2 * b + c) / 2;
  }

  /// Nutation in longitude and obliquity, degrees, for a TT Julian day.
  static (double, double) _nutation(double jdTt) =>
      (_interpolate(jdTt, 3), _interpolate(jdTt, 4));

  static (double, double) _nutationSeries(double jdTt) {
    final t = (jdTt - _j2000) / 36525;
    // Fundamental arguments (IAU 1980), arcseconds plus whole revolutions.
    double arg(double a, double b, double c, double d, int revolutions) =>
        ((a + (b + (c + d * t) * t) * t) * _arcsec +
            ((revolutions * t) % 1.0) * 360) %
        360;
    final l = arg(485866.733, 715922.633, 31.310, 0.064, 1325);
    final lp = arg(1287099.804, 1292581.224, -0.577, -0.012, 99);
    final f = arg(335778.877, 295263.137, -13.257, 0.011, 1342);
    final d = arg(1072261.307, 1105601.328, -6.891, 0.019, 1236);
    final om = arg(450160.280, -482890.539, 7.455, 0.008, -5);
    var psi = 0.0, eps = 0.0;
    for (final row in nutation1980) {
      final a =
          (row[0] * l + row[1] * lp + row[2] * f + row[3] * d + row[4] * om) *
          _rad;
      psi += (row[5] + row[6] * t) * math.sin(a);
      eps += (row[7] + row[8] * t) * math.cos(a);
    }
    return (psi * 1e-4 * _arcsec, eps * 1e-4 * _arcsec);
  }

  static double _meanObliquity(double t) {
    final u = t / 100;
    // Laskar (Meeus 22.3), arcseconds.
    return (84381.448 +
            u *
                (-4680.93 +
                    u *
                        (-1.55 +
                            u *
                                (1999.25 +
                                    u *
                                        (-51.38 +
                                            u *
                                                (-249.67 +
                                                    u *
                                                        (-39.05 +
                                                            u *
                                                                (7.12 +
                                                                    u *
                                                                        (27.87 +
                                                                            u * (5.79 + u * 2.45)))))))))) *
        _arcsec;
  }

  static double _trueObliquity(double jdTt) =>
      _meanObliquity((jdTt - _j2000) / 36525) + _nutation(jdTt).$2;

  // --- Sun -------------------------------------------------------------------

  static double _vsop(List<List<List<double>>> series, double tau) {
    var result = 0.0;
    var power = 1.0;
    for (final terms in series) {
      var sum = 0.0;
      for (final term in terms) {
        sum += term[0] * math.cos(term[1] + term[2] * tau);
      }
      result += sum * power;
      power *= tau;
    }
    return result;
  }

  /// Apparent geocentric ecliptic longitude, latitude (degrees, true equinox
  /// of date) and distance (AU) of the Sun from the VSOP87D series.
  static (double, double, double) _sunSeries(double jdTt, double nutationPsi) {
    final tau = (jdTt - _j2000) / 365250;
    final t = tau * 10;
    final l = _vsop(earthL, tau) * _deg;
    final b = _vsop(earthB, tau) * _deg;
    final r = _vsop(earthR, tau);
    var longitude = l + 180;
    var latitude = -b;
    // VSOP87 dynamical frame to FK5 (Meeus 32.3).
    final lambdaPrime = (longitude - 1.397 * t - 0.00031 * t * t) * _rad;
    longitude +=
        (-0.09033 +
            0.03916 *
                (math.cos(lambdaPrime) + math.sin(lambdaPrime)) *
                math.tan(latitude * _rad)) *
        _arcsec;
    latitude +=
        0.03916 * (math.cos(lambdaPrime) - math.sin(lambdaPrime)) * _arcsec;
    // Annual aberration (Meeus 25.10) and nutation in longitude.
    longitude += -20.4898 / r * _arcsec + nutationPsi;
    return (normalize(longitude), latitude, r);
  }

  static double sunLongitude(DateTime instant) =>
      normalize(_interpolate(terrestrialJulianDay(instant), 0));

  static double sunDistanceAu(DateTime instant) =>
      _interpolate(terrestrialJulianDay(instant), 2);

  // --- Moon ------------------------------------------------------------------

  static double moonLongitude(DateTime instant) =>
      normalize(_moonPosition(instant).longitude);

  static double moonLatitude(DateTime instant) =>
      _moonPosition(instant).latitude;

  static double moonDistanceKm(DateTime instant) =>
      _moonPosition(instant).distanceKm;

  // --- Ayanamsa --------------------------------------------------------------

  /// Mean Lahiri ayanamsa: J2000 value plus IAU 2006 general precession.
  static double lahiriAyanamsa(DateTime instant) {
    final t = (terrestrialJulianDay(instant) - _j2000) / 36525;
    return 23.857092328 + t * (1.3968879428 + t * 0.00030708955);
  }

  /// Apparent tropical positions refer to the true equinox. Remove nutation
  /// along with the mean Lahiri offset when forming sidereal longitudes.
  static double apparentLahiriAyanamsa(DateTime instant) =>
      lahiriAyanamsa(instant) + _nutation(terrestrialJulianDay(instant)).$1;

  // --- Coordinates -----------------------------------------------------------

  static ({double rightAscension, double declination}) _equatorial(
    double longitude,
    double latitude,
    double epsilon,
  ) {
    final lon = longitude * _rad, lat = latitude * _rad, e = epsilon * _rad;
    final ra = math.atan2(
      math.sin(lon) * math.cos(e) - math.tan(lat) * math.sin(e),
      math.cos(lon),
    );
    final dec = math.asin(
      math.sin(lat) * math.cos(e) + math.cos(lat) * math.sin(e) * math.sin(lon),
    );
    return (rightAscension: _normalizeRadians(ra), declination: dec);
  }

  static ({double rightAscension, double declination}) sunEquatorial(
    DateTime instant,
  ) {
    final jdTt = terrestrialJulianDay(instant);
    return _equatorial(
      normalize(_interpolate(jdTt, 0)),
      _interpolate(jdTt, 1),
      _trueObliquity(jdTt),
    );
  }

  static ({double rightAscension, double declination}) moonEquatorial(
    DateTime instant,
  ) {
    final position = _moonPosition(instant);
    return _equatorial(
      position.longitude,
      position.latitude,
      _trueObliquity(terrestrialJulianDay(instant)),
    );
  }

  /// Greenwich apparent sidereal time, degrees.
  static double siderealDegrees(DateTime instant) {
    final jd = julianDay(instant);
    final t = (jd - _j2000) / 36525;
    final mean =
        280.46061837 +
        360.98564736629 * (jd - _j2000) +
        0.000387933 * t * t -
        t * t * t / 38710000;
    final jdTt = terrestrialJulianDay(instant);
    final equation = _nutation(jdTt).$1 * math.cos(_trueObliquity(jdTt) * _rad);
    return normalize(mean + equation);
  }

  /// Tropical ecliptic longitude of the eastern horizon intersection.
  /// Uses local sidereal time and mean obliquity (Meeus coordinate geometry).
  static double ascendantLongitude(
    DateTime instant,
    double latitude,
    double longitude,
  ) {
    final theta = (siderealDegrees(instant) + longitude) * _rad;
    final t = (terrestrialJulianDay(instant) - _j2000) / 36525;
    final epsilon = _meanObliquity(t) * _rad;
    return normalize(
      math.atan2(
                -math.cos(theta),
                math.sin(epsilon) * math.tan(latitude * _rad) +
                    math.cos(epsilon) * math.sin(theta),
              ) *
              _deg +
          180,
    );
  }

  /// Topocentric geometric altitude of the body's centre, degrees, before
  /// refraction. The observer's geocentric position accounts for the Earth's
  /// flattening (Meeus ch. 11) and parallax is applied rigorously to right
  /// ascension and declination (Meeus ch. 40), for the Moon and the Sun.
  static double altitudeDegrees({
    required DateTime instant,
    required double latitude,
    required double longitude,
    required bool moon,
  }) {
    final equatorial = moon ? moonEquatorial(instant) : sunEquatorial(instant);
    final distanceKm = moon
        ? moonDistanceKm(instant)
        : sunDistanceAu(instant) * 149597870.7;
    final lat = latitude * _rad;
    const flattening = 0.99664719; // b/a, IAU 1976 ellipsoid
    final u = math.atan(flattening * math.tan(lat));
    final rhoSin = flattening * math.sin(u);
    final rhoCos = math.cos(u);
    final sinParallax = 6378.14 / distanceKm;
    final hourAngle =
        signedAngle(
          siderealDegrees(instant) +
              longitude -
              equatorial.rightAscension * _deg,
        ) *
        _rad;
    final dec = equatorial.declination;
    final denominator =
        math.cos(dec) - rhoCos * sinParallax * math.cos(hourAngle);
    final deltaRa = math.atan2(
      -rhoCos * sinParallax * math.sin(hourAngle),
      denominator,
    );
    final topocentricDec = math.atan2(
      (math.sin(dec) - rhoSin * sinParallax) * math.cos(deltaRa),
      denominator,
    );
    final topocentricHour = hourAngle - deltaRa;
    final sinAltitude =
        math.sin(lat) * math.sin(topocentricDec) +
        math.cos(lat) * math.cos(topocentricDec) * math.cos(topocentricHour);
    return math.asin(sinAltitude.clamp(-1.0, 1.0)) * _deg;
  }

  /// Apparent semidiameter in degrees (Sun from distance; Moon topocentric
  /// approximated by the geocentric value).
  static double semidiameterDegrees(DateTime instant, {required bool moon}) {
    if (moon) {
      return math.asin(1737.4 / moonDistanceKm(instant)) * _deg;
    }
    return 959.63 / sunDistanceAu(instant) * _arcsec;
  }

  // The Moon is evaluated at hourly nodes and interpolated quadratically
  // (interpolation error below 0.002 arcseconds).
  static const double _moonStep = 1 / 24;
  static final Map<int, List<double>> _moonNodes = {};

  static double _elpSum(List<List<double>> terms, double t) {
    final t2 = t * t, t3 = t2 * t, t4 = t3 * t;
    var sum = 0.0;
    for (final row in terms) {
      final argument =
          row[2] + row[3] * t + row[4] * t2 + row[5] * t3 + row[6] * t4;
      final scale = row[1] == 0 ? 1.0 : (row[1] == 1 ? t : t2);
      sum += row[0] * scale * math.sin(argument % (2 * math.pi));
    }
    return sum;
  }

  /// Geocentric ecliptic longitude/latitude (degrees, mean equinox of date,
  /// without nutation) and distance (km) of the Moon at TT Julian day [jd]:
  /// ELP 2000-82B with light time; secular longitude terms refitted to JPL.
  static List<double> _moonSeries(double jd) {
    final t0 = (jd - _j2000) / 36525;
    final distance = _elpSum(elpDistance, t0) * elpDistanceScale;
    // Light time (about 1.3 s): the Moon is seen where it was.
    final t = (jd - distance / 299792.458 / 86400 - _j2000) / 36525;
    const w = elpMeanLongitude;
    final longitude =
        _elpSum(elpLongitude, t) * _arcsec * _rad +
        w[0] +
        w[1] * t +
        w[2] * t * t +
        w[3] * t * t * t +
        w[4] * t * t * t * t;
    // ELP 2000-82B was fitted to DE200. Its mean longitude drifts from JPL
    // DE431 by 0.12" + 0.68" T + 0.97" T^2 (fitted to Swiss Ephemeris over
    // 1900-2100, held-out error 0.11" mean), the same kind of secular
    // refit as ELP/MPP02. Then precess from the J2000 departure point to
    // the mean equinox of date (5029.0966" T + 1.11113" T^2).
    final correction = (0.12092 + 0.68062 * t + 0.97415 * t * t) * _arcsec;
    final precession = (5029.0966 * t + 1.11113 * t * t) * _arcsec;
    return [
      normalize(longitude * _deg - correction + precession),
      _elpSum(elpLatitude, t) * _arcsec,
      distance,
    ];
  }

  static List<double> _moonNode(int index) {
    final cached = _moonNodes[index];
    if (cached != null) return cached;
    if (_moonNodes.length > 4096) _moonNodes.clear();
    return _moonNodes[index] = _moonSeries(index * _moonStep);
  }

  static ({double longitude, double latitude, double distanceKm}) _moonPosition(
    DateTime instant,
  ) {
    final jd = terrestrialJulianDay(instant);
    final x = jd / _moonStep;
    final i = x.round();
    final p = x - i;
    final a = _moonNode(i - 1), b = _moonNode(i), c = _moonNode(i + 1);
    double quadratic(double fa, double fb, double fc) =>
        fb + p * (fc - fa) / 2 + p * p * (fa - 2 * fb + fc) / 2;
    final longitude = quadratic(
      b[0] + signedAngle(a[0] - b[0]),
      b[0],
      b[0] + signedAngle(c[0] - b[0]),
    );
    return (
      longitude: normalize(longitude + _nutation(jd).$1),
      latitude: quadratic(a[1], b[1], c[1]),
      distanceKm: quadratic(a[2], b[2], c[2]),
    );
  }

  static double _normalizeRadians(double radians) =>
      (radians % (math.pi * 2) + math.pi * 2) % (math.pi * 2);

  // Delta T (seconds) on 1 January of each year from 1900.
  static const _deltaT = <double>[
    -1.95, -0.72, 0.64, 2.08, 3.53, 4.94, 6.26, 7.50, 8.71, 9.92, // 1900
    11.16,
    12.45,
    13.77,
    15.08,
    16.33,
    17.49,
    18.53,
    19.45,
    20.27,
    20.99, // 1910
    21.63,
    22.20,
    22.70,
    23.13,
    23.50,
    23.80,
    24.03,
    24.20,
    24.32,
    24.39, // 1920
    24.42,
    24.42,
    24.38,
    24.32,
    24.25,
    24.17,
    24.09,
    24.04,
    24.06,
    24.18, // 1930
    24.43,
    24.83,
    25.35,
    25.93,
    26.51,
    27.05,
    27.51,
    27.89,
    28.24,
    28.58, // 1940
    28.93,
    29.32,
    29.70,
    30.18,
    30.62,
    31.07,
    31.35,
    31.68,
    32.18,
    32.68, // 1950
    33.15,
    33.59,
    34.00,
    34.47,
    35.03,
    35.73,
    36.54,
    37.43,
    38.29,
    39.20, // 1960
    40.18,
    41.17,
    42.23,
    43.37,
    44.49,
    45.48,
    46.46,
    47.52,
    48.54,
    49.59, // 1970
    50.54,
    51.38,
    52.17,
    52.96,
    53.79,
    54.34,
    54.87,
    55.32,
    55.82,
    56.30, // 1980
    56.86,
    57.57,
    58.31,
    59.12,
    59.99,
    60.79,
    61.63,
    62.30,
    62.97,
    63.47, // 1990
    63.83,
    64.09,
    64.30,
    64.47,
    64.57,
    64.69,
    64.85,
    65.15,
    65.46,
    65.78, // 2000
    66.07,
    66.32,
    66.60,
    66.91,
    67.28,
    67.64,
    68.10,
    68.59,
    68.97,
    69.22, // 2010
    69.36,
    69.36,
    69.29,
    69.18,
    69.10,
    69.00,
    68.90,
    68.80,
    68.80,
    69.04, // 2020
    69.28,
    69.52,
    69.76,
    70.01,
    70.26,
    70.51,
    70.76,
    71.02,
    71.28,
    71.54, // 2030
    71.80,
    72.07,
    72.33,
    72.61,
    72.88,
    73.16,
    73.44,
    73.72,
    74.00,
    74.29, // 2040
    74.58, // 2050
  ];
}
