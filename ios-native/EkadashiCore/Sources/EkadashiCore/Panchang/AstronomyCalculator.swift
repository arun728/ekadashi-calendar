import Foundation

/// Deterministic solar and lunar positions for the Panchang engine, a direct
/// port of lib/services/panchang/astronomy_calculator.dart. Angles returned to
/// callers are in degrees.
///
/// - Sun: VSOP87D Earth series (Bretagnon & Francou 1988), converted to the
///   FK5 frame, with annual aberration and IAU 1980 nutation (Meeus,
///   *Astronomical Algorithms* 2nd ed., ch. 22, 25 and 32).
/// - Moon: ELP 2000-82B (Chapront-Touze & Chapront), 769 terms, light time,
///   secular terms refitted to JPL DE431, IAU 1980 nutation.
/// - Delta T: yearly observed (IERS/USNO) and predicted values, 1900-2100,
///   as tabulated by Swiss Ephemeris 2.10, linear between years.
/// - Lahiri: 23°51′25.53″ at J2000 plus IAU 2006 general precession, the
///   Swiss Ephemeris SE_SIDM_LAHIRI definition to better than 0.001″.
/// See docs/PANCHANG_ACCURACY.md for the independent comparison.
public enum AstronomyCalculator {
    static let rad = Double.pi / 180
    static let deg = 180 / Double.pi
    static let j2000 = 2451545.0
    static let arcsec = 1.0 / 3600

    /// Refraction at the horizon for the standard atmosphere (1013.25 hPa,
    /// 15 °C), 33.6′: the value Swiss Ephemeris applies in swe_rise_trans.
    public static let horizonRefraction = 0.5599

    public static func julianDay(_ instant: Date) -> Double {
        // Dart uses whole milliseconds since the epoch.
        (instant.timeIntervalSince1970 * 1000).rounded(.towardZero) / 86_400_000 + 2440587.5
    }

    /// Delta T in seconds for a fractional year.
    public static func deltaTSeconds(_ year: Double) -> Double {
        let first = 1900.0
        let table = deltaTTable
        if year >= first && year < first + Double(table.count - 1) {
            let i = Int(floor(year - first))
            let f = year - first - Double(i)
            return table[i] + (table[i + 1] - table[i]) * f
        }
        if year >= first + Double(table.count - 1) {
            let last = table.count - 1
            return table[last] + (table[last] - table[last - 1]) * (year - first - Double(last))
        }
        let u = (year - 1820) / 100
        return -20 + 32 * u * u
    }

    /// TT = UT + Delta T. UTC is treated as UT1 (sub-second difference).
    public static func terrestrialJulianDay(_ instant: Date) -> Double {
        let jd = julianDay(instant)
        let year = 2000 + (jd - j2000) / 365.25
        return jd + deltaTSeconds(year) / 86400
    }

    public static func fromJulianDay(_ jd: Double) -> Date {
        Date(timeIntervalSince1970: ((jd - 2440587.5) * 86_400_000).rounded() / 1000)
    }

    public static func normalize(_ angle: Double) -> Double { dartMod(dartMod(angle, 360) + 360, 360) }

    public static func signedAngle(_ angle: Double) -> Double {
        let value = normalize(angle)
        return value > 180 ? value - 360 : value
    }

    // MARK: Nutation (IAU 1980)

    // Nutation and the Sun change smoothly, so both are evaluated at six-hour
    // nodes and interpolated quadratically (error below 0.0001 arcseconds).
    static let nodeStep = 0.25
    private static let nodes = Locked<[Int: [Double]]>([:])

    static func node(_ index: Int) -> [Double] {
        if let cached = nodes.withLock({ $0[index] }) { return cached }
        let jd = Double(index) * nodeStep
        let nutation = nutationSeries(jd)
        let sun = sunSeries(jd, nutationPsi: nutation.psi)
        let value = [sun.longitude, sun.latitude, sun.distance, nutation.psi, nutation.epsilon]
        nodes.withLock { cache in
            if cache.count > 4096 { cache.removeAll() }
            cache[index] = value
        }
        return value
    }

    /// Quadratic interpolation of node component [k]; longitude is unwrapped.
    static func interpolate(_ jdTt: Double, _ k: Int) -> Double {
        let x = jdTt / nodeStep
        let i = Int(x.rounded())
        let p = x - Double(i)
        var a = node(i - 1)[k]
        let b = node(i)[k]
        var c = node(i + 1)[k]
        if k == 0 {
            a = b + signedAngle(a - b)
            c = b + signedAngle(c - b)
        }
        return b + p * (c - a) / 2 + p * p * (a - 2 * b + c) / 2
    }

    /// Nutation in longitude and obliquity, degrees, for a TT Julian day.
    static func nutation(_ jdTt: Double) -> (psi: Double, epsilon: Double) {
        (interpolate(jdTt, 3), interpolate(jdTt, 4))
    }

    static func nutationSeries(_ jdTt: Double) -> (psi: Double, epsilon: Double) {
        let t = (jdTt - j2000) / 36525
        // Fundamental arguments (IAU 1980), arcseconds plus whole revolutions.
        func arg(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ revolutions: Double) -> Double {
            dartMod((a + (b + (c + d * t) * t) * t) * arcsec + dartMod(revolutions * t, 1.0) * 360, 360)
        }
        let l = arg(485866.733, 715922.633, 31.310, 0.064, 1325)
        let lp = arg(1287099.804, 1292581.224, -0.577, -0.012, 99)
        let f = arg(335778.877, 295263.137, -13.257, 0.011, 1342)
        let d = arg(1072261.307, 1105601.328, -6.891, 0.019, 1236)
        let om = arg(450160.280, -482890.539, 7.455, 0.008, -5)
        var psi = 0.0, eps = 0.0
        let rows = EphemerisSeries.nutation1980
        var r = 0
        while r < rows.count {
            let a = (rows[r] * l + rows[r + 1] * lp + rows[r + 2] * f + rows[r + 3] * d + rows[r + 4] * om) * rad
            psi += (rows[r + 5] + rows[r + 6] * t) * sin(a)
            eps += (rows[r + 7] + rows[r + 8] * t) * cos(a)
            r += 9
        }
        return (psi * 1e-4 * arcsec, eps * 1e-4 * arcsec)
    }

    static func meanObliquity(_ t: Double) -> Double {
        let u = t / 100
        // Laskar (Meeus 22.3), arcseconds.
        var value = 2.45
        for coefficient in [5.79, 27.87, 7.12, -39.05, -249.67, -51.38, 1999.25, -1.55, -4680.93] {
            value = coefficient + u * value
        }
        return (84381.448 + u * value) * arcsec
    }

    static func trueObliquity(_ jdTt: Double) -> Double {
        meanObliquity((jdTt - j2000) / 36525) + nutation(jdTt).epsilon
    }

    // MARK: Sun

    static func vsop(_ series: [[Double]], _ tau: Double) -> Double {
        var result = 0.0
        var power = 1.0
        for terms in series {
            var sum = 0.0
            var r = 0
            while r < terms.count {
                sum += terms[r] * cos(terms[r + 1] + terms[r + 2] * tau)
                r += 3
            }
            result += sum * power
            power *= tau
        }
        return result
    }

    /// Apparent geocentric ecliptic longitude, latitude (degrees, true equinox
    /// of date) and distance (AU) of the Sun from the VSOP87D series.
    static func sunSeries(_ jdTt: Double, nutationPsi: Double) -> (longitude: Double, latitude: Double, distance: Double) {
        let tau = (jdTt - j2000) / 365250
        let t = tau * 10
        let l = vsop(EphemerisSeries.earthL, tau) * deg
        let b = vsop(EphemerisSeries.earthB, tau) * deg
        let r = vsop(EphemerisSeries.earthR, tau)
        var longitude = l + 180
        var latitude = -b
        // VSOP87 dynamical frame to FK5 (Meeus 32.3).
        let lambdaPrime = (longitude - 1.397 * t - 0.00031 * t * t) * rad
        longitude += (-0.09033 + 0.03916 * (cos(lambdaPrime) + sin(lambdaPrime)) * tan(latitude * rad)) * arcsec
        latitude += 0.03916 * (cos(lambdaPrime) - sin(lambdaPrime)) * arcsec
        // Annual aberration (Meeus 25.10) and nutation in longitude.
        longitude += -20.4898 / r * arcsec + nutationPsi
        return (normalize(longitude), latitude, r)
    }

    public static func sunLongitude(_ instant: Date) -> Double {
        normalize(interpolate(terrestrialJulianDay(instant), 0))
    }

    public static func sunDistanceAu(_ instant: Date) -> Double {
        interpolate(terrestrialJulianDay(instant), 2)
    }

    // MARK: Moon

    public static func moonLongitude(_ instant: Date) -> Double { normalize(moonPosition(instant).longitude) }
    public static func moonLatitude(_ instant: Date) -> Double { moonPosition(instant).latitude }
    public static func moonDistanceKm(_ instant: Date) -> Double { moonPosition(instant).distanceKm }

    // MARK: Ayanamsa

    /// Mean Lahiri ayanamsa: J2000 value plus IAU 2006 general precession.
    public static func lahiriAyanamsa(_ instant: Date) -> Double {
        let t = (terrestrialJulianDay(instant) - j2000) / 36525
        return 23.857092328 + t * (1.3968879428 + t * 0.00030708955)
    }

    /// Apparent tropical positions refer to the true equinox. Remove nutation
    /// along with the mean Lahiri offset when forming sidereal longitudes.
    public static func apparentLahiriAyanamsa(_ instant: Date) -> Double {
        lahiriAyanamsa(instant) + nutation(terrestrialJulianDay(instant)).psi
    }

    // MARK: Coordinates

    static func equatorial(_ longitude: Double, _ latitude: Double, _ epsilon: Double)
        -> (rightAscension: Double, declination: Double) {
        let lon = longitude * rad, lat = latitude * rad, e = epsilon * rad
        let ra = atan2(sin(lon) * cos(e) - tan(lat) * sin(e), cos(lon))
        let dec = asin(sin(lat) * cos(e) + cos(lat) * sin(e) * sin(lon))
        return (dartMod(dartMod(ra, 2 * .pi) + 2 * .pi, 2 * .pi), dec)
    }

    static func sunEquatorial(_ instant: Date) -> (rightAscension: Double, declination: Double) {
        let jdTt = terrestrialJulianDay(instant)
        return equatorial(normalize(interpolate(jdTt, 0)), interpolate(jdTt, 1), trueObliquity(jdTt))
    }

    static func moonEquatorial(_ instant: Date) -> (rightAscension: Double, declination: Double) {
        let position = moonPosition(instant)
        return equatorial(position.longitude, position.latitude, trueObliquity(terrestrialJulianDay(instant)))
    }

    /// Greenwich apparent sidereal time, degrees.
    public static func siderealDegrees(_ instant: Date) -> Double {
        let jd = julianDay(instant)
        let t = (jd - j2000) / 36525
        let mean = 280.46061837 + 360.98564736629 * (jd - j2000) + 0.000387933 * t * t - t * t * t / 38_710_000
        let jdTt = terrestrialJulianDay(instant)
        let equation = nutation(jdTt).psi * cos(trueObliquity(jdTt) * rad)
        return normalize(mean + equation)
    }

    /// Tropical ecliptic longitude of the eastern horizon intersection.
    public static func ascendantLongitude(_ instant: Date, latitude: Double, longitude: Double) -> Double {
        let theta = (siderealDegrees(instant) + longitude) * rad
        let t = (terrestrialJulianDay(instant) - j2000) / 36525
        let epsilon = meanObliquity(t) * rad
        return normalize(atan2(-cos(theta), sin(epsilon) * tan(latitude * rad) + cos(epsilon) * sin(theta)) * deg + 180)
    }

    /// Topocentric geometric altitude of the body's centre, degrees, before
    /// refraction, with the Earth's flattening (Meeus ch. 11) and rigorous
    /// parallax in right ascension and declination (Meeus ch. 40).
    public static func altitudeDegrees(instant: Date, latitude: Double, longitude: Double, moon: Bool) -> Double {
        let eq = moon ? moonEquatorial(instant) : sunEquatorial(instant)
        let distanceKm = moon ? moonDistanceKm(instant) : sunDistanceAu(instant) * 149_597_870.7
        let lat = latitude * rad
        let flattening = 0.99664719 // b/a, IAU 1976 ellipsoid
        let u = atan(flattening * tan(lat))
        let rhoSin = flattening * sin(u)
        let rhoCos = cos(u)
        let sinParallax = 6378.14 / distanceKm
        let hourAngle = signedAngle(siderealDegrees(instant) + longitude - eq.rightAscension * deg) * rad
        let dec = eq.declination
        let denominator = cos(dec) - rhoCos * sinParallax * cos(hourAngle)
        let deltaRa = atan2(-rhoCos * sinParallax * sin(hourAngle), denominator)
        let topocentricDec = atan2((sin(dec) - rhoSin * sinParallax) * cos(deltaRa), denominator)
        let topocentricHour = hourAngle - deltaRa
        let sinAltitude = sin(lat) * sin(topocentricDec) + cos(lat) * cos(topocentricDec) * cos(topocentricHour)
        return asin(min(1, max(-1, sinAltitude))) * deg
    }

    /// Apparent semidiameter in degrees.
    public static func semidiameterDegrees(_ instant: Date, moon: Bool) -> Double {
        if moon { return asin(1737.4 / moonDistanceKm(instant)) * deg }
        return 959.63 / sunDistanceAu(instant) * arcsec
    }

    // The Moon is evaluated at hourly nodes and interpolated quadratically
    // (interpolation error below 0.002 arcseconds).
    static let moonStep = 1.0 / 24
    private static let moonNodes = Locked<[Int: [Double]]>([:])

    static func elpSum(_ terms: [Double], _ t: Double) -> Double {
        let t2 = t * t, t3 = t2 * t, t4 = t3 * t
        var sum = 0.0
        var r = 0
        while r < terms.count {
            let argument = terms[r + 2] + terms[r + 3] * t + terms[r + 4] * t2 + terms[r + 5] * t3 + terms[r + 6] * t4
            let scale = terms[r + 1] == 0 ? 1.0 : (terms[r + 1] == 1 ? t : t2)
            sum += terms[r] * scale * sin(dartMod(argument, 2 * .pi))
            r += 7
        }
        return sum
    }

    /// Geocentric ecliptic longitude/latitude (degrees, mean equinox of date,
    /// without nutation) and distance (km) of the Moon at TT Julian day [jd].
    static func moonSeries(_ jd: Double) -> [Double] {
        let t0 = (jd - j2000) / 36525
        let distance = elpSum(LunarSeries.distance, t0) * LunarSeries.distanceScale
        // Light time (about 1.3 s): the Moon is seen where it was.
        let t = (jd - distance / 299_792.458 / 86400 - j2000) / 36525
        let w = LunarSeries.meanLongitude
        let longitude = elpSum(LunarSeries.longitude, t) * arcsec * rad
            + w[0] + w[1] * t + w[2] * t * t + w[3] * t * t * t + w[4] * t * t * t * t
        // Secular refit to JPL DE431 and precession from the J2000 departure
        // point to the mean equinox of date (see the Dart source).
        let correction = (0.12092 + 0.68062 * t + 0.97415 * t * t) * arcsec
        let precession = (5029.0966 * t + 1.11113 * t * t) * arcsec
        return [normalize(longitude * deg - correction + precession), elpSum(LunarSeries.latitude, t) * arcsec, distance]
    }

    static func moonNode(_ index: Int) -> [Double] {
        if let cached = moonNodes.withLock({ $0[index] }) { return cached }
        let value = moonSeries(Double(index) * moonStep)
        moonNodes.withLock { cache in
            if cache.count > 4096 { cache.removeAll() }
            cache[index] = value
        }
        return value
    }

    static func moonPosition(_ instant: Date) -> (longitude: Double, latitude: Double, distanceKm: Double) {
        let jd = terrestrialJulianDay(instant)
        let x = jd / moonStep
        let i = Int(x.rounded())
        let p = x - Double(i)
        let a = moonNode(i - 1), b = moonNode(i), c = moonNode(i + 1)
        func quadratic(_ fa: Double, _ fb: Double, _ fc: Double) -> Double {
            fb + p * (fc - fa) / 2 + p * p * (fa - 2 * fb + fc) / 2
        }
        let longitude = quadratic(b[0] + signedAngle(a[0] - b[0]), b[0], b[0] + signedAngle(c[0] - b[0]))
        return (normalize(longitude + nutation(jd).psi), quadratic(a[1], b[1], c[1]), quadratic(a[2], b[2], c[2]))
    }

    // Delta T (seconds) on 1 January of each year, 1900-2100 (observed to
    // 2025, then the standard prediction used by Swiss Ephemeris).
    static let deltaTTable: [Double] = [
        -1.95, -0.72, 0.64, 2.08, 3.53, 4.94, 6.26, 7.50, 8.71, 9.92, // 1900
        11.16, 12.45, 13.77, 15.08, 16.33, 17.49, 18.53, 19.45, 20.27, 20.99, // 1910
        21.63, 22.20, 22.70, 23.13, 23.50, 23.80, 24.03, 24.20, 24.32, 24.39, // 1920
        24.42, 24.42, 24.38, 24.32, 24.25, 24.17, 24.09, 24.04, 24.06, 24.18, // 1930
        24.43, 24.83, 25.35, 25.93, 26.51, 27.05, 27.51, 27.89, 28.24, 28.58, // 1940
        28.93, 29.32, 29.70, 30.18, 30.62, 31.07, 31.35, 31.68, 32.18, 32.68, // 1950
        33.15, 33.59, 34.00, 34.47, 35.03, 35.73, 36.54, 37.43, 38.29, 39.20, // 1960
        40.18, 41.17, 42.23, 43.37, 44.49, 45.48, 46.46, 47.52, 48.54, 49.59, // 1970
        50.54, 51.38, 52.17, 52.96, 53.79, 54.34, 54.87, 55.32, 55.82, 56.30, // 1980
        56.86, 57.57, 58.31, 59.12, 59.99, 60.79, 61.63, 62.30, 62.97, 63.47, // 1990
        63.83, 64.09, 64.30, 64.47, 64.57, 64.69, 64.85, 65.15, 65.46, 65.78, // 2000
        66.07, 66.32, 66.60, 66.91, 67.28, 67.64, 68.10, 68.59, 68.97, 69.22, // 2010
        69.36, 69.36, 69.29, 69.18, 69.10, 69.00, 68.90, 68.80, 68.80, 69.04, // 2020
        69.28, 69.52, 69.76, 70.01, 70.26, 70.51, 70.76, 71.02, 71.28, 71.54, // 2030
        71.80, 72.07, 72.33, 72.61, 72.88, 73.16, 73.44, 73.72, 74.00, 74.29, // 2040
        74.58, 74.87, 75.17, 75.47, 75.77, 76.07, 76.38, 76.69, 77.01, 77.32, // 2050
        77.64, 77.97, 78.29, 78.62, 78.95, 79.29, 79.62, 79.97, 80.31, 80.66, // 2060
        81.01, 81.36, 81.72, 82.08, 82.45, 82.81, 83.19, 83.56, 83.94, 84.32, // 2070
        84.70, 85.09, 85.49, 85.88, 86.28, 86.68, 87.09, 87.50, 87.92, 88.33, // 2080
        88.76, 89.18, 89.61, 90.04, 90.48, 90.92, 91.36, 91.81, 92.27, 92.72, // 2090
        93.18, // 2100
    ]
}
