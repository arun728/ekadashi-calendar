import 'astronomy_calculator.dart';
import 'panchang_city.dart';
import 'panchang_models.dart';

/// Offline Panchang calculator for explicit civil dates and location timezones.
/// The argument is a calendar date; its fields are used as-is, regardless of
/// the host device timezone.
class PanchangEngine {
  const PanchangEngine();

  static const _tithis = [
    'Pratipada',
    'Dvitiya',
    'Tritiya',
    'Chaturthi',
    'Panchami',
    'Shashthi',
    'Saptami',
    'Ashtami',
    'Navami',
    'Dashami',
    'Ekadashi',
    'Dwadashi',
    'Trayodashi',
    'Chaturdashi',
    'Purnima',
  ];
  static const _nakshatras = [
    'Ashwini',
    'Bharani',
    'Krittika',
    'Rohini',
    'Mrigashira',
    'Ardra',
    'Punarvasu',
    'Pushya',
    'Ashlesha',
    'Magha',
    'Purva Phalguni',
    'Uttara Phalguni',
    'Hasta',
    'Chitra',
    'Swati',
    'Vishakha',
    'Anuradha',
    'Jyeshtha',
    'Mula',
    'Purva Ashadha',
    'Uttara Ashadha',
    'Shravana',
    'Dhanishtha',
    'Shatabhisha',
    'Purva Bhadrapada',
    'Uttara Bhadrapada',
    'Revati',
  ];
  static const _yogas = [
    'Vishkambha',
    'Priti',
    'Ayushman',
    'Saubhagya',
    'Shobhana',
    'Atiganda',
    'Sukarman',
    'Dhriti',
    'Shula',
    'Ganda',
    'Vriddhi',
    'Dhruva',
    'Vyaghata',
    'Harshana',
    'Vajra',
    'Siddhi',
    'Vyatipata',
    'Variyana',
    'Parigha',
    'Shiva',
    'Siddha',
    'Sadhya',
    'Shubha',
    'Shukla',
    'Brahma',
    'Indra',
    'Vaidhriti',
  ];
  static const _karanaChara = [
    'Bava',
    'Balava',
    'Kaulava',
    'Taitila',
    'Garaja',
    'Vanija',
    'Vishti',
  ];
  static const _lunarMonths = [
    'Chaitra',
    'Vaishakha',
    'Jyeshtha',
    'Ashadha',
    'Shravana',
    'Bhadrapada',
    'Ashvina',
    'Kartika',
    'Margashirsha',
    'Pausha',
    'Magha',
    'Phalguna',
  ];
  static const _varas = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  PanchangDay calculate(
    DateTime date, {
    PanchangCity city = PanchangCity.newDelhi,
  }) {
    city.validate();
    final calendarDate = DateTime.utc(date.year, date.month, date.day);
    final startUtc = startFor(calendarDate, city: city);
    final endUtc = endFor(calendarDate, city: city);
    final sunrise = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: false,
      targetAltitude: -0.833,
      rising: true,
    );
    var sunset = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: false,
      targetAltitude: -0.833,
      rising: false,
    );
    if (sunrise != null && sunset != null && sunset.isBefore(sunrise)) {
      sunset = _findCrossing(
        sunrise,
        city.midnight(calendarDate, dayOffset: 2),
        city,
        moon: false,
        targetAltitude: -0.833,
        rising: false,
      );
    }
    final moonrise = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: true,
      targetAltitude: -0.833,
      rising: true,
    );
    final moonset = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: true,
      targetAltitude: -0.833,
      rising: false,
    );
    final hasSolarDay =
        sunrise != null && sunset != null && sunset.isAfter(sunrise);
    final localSunrise = sunrise ?? city.dateAtHour(calendarDate, 6);
    final localSunset = sunset ?? city.dateAtHour(calendarDate, 18);
    final madhyahna = localSunrise.add(
      localSunset.difference(localSunrise) ~/ 2,
    );
    final aparahna = localSunrise.add(
      Duration(
        microseconds:
            (localSunset.difference(localSunrise).inMicroseconds * 0.6).round(),
      ),
    );
    final nightEnd = _findCrossing(
      localSunset,
      city.midnight(calendarDate, dayOffset: 2),
      city,
      moon: false,
      targetAltitude: -0.833,
      rising: true,
    );
    final nishita = nightEnd == null
        ? localSunset.add(const Duration(hours: 6))
        : localSunset.add(nightEnd.difference(localSunset) ~/ 2);

    final tithi = _tithiAt(localSunrise);
    final nakshatra = _nakshatraAt(localSunrise);
    final yoga = _yogaAt(localSunrise);
    final karana = _karanaAt(localSunrise);
    final month = _monthFor(localSunrise);
    final purnimantaIndex = tithi.paksha == 'Krishna' && !month.adhika
        ? (month.index + 1) % 12
        : month.index;
    final purnimanta =
        '${month.adhika ? "Adhika " : ""}${_lunarMonths[purnimantaIndex]}';
    final rahukala = _dayPeriod(
      localSunrise,
      localSunset,
      weekday: calendarDate.weekday,
      segmentByWeekday: const [2, 7, 5, 6, 4, 3, 8],
      name: 'Rahu Kalam',
    );
    final yamaganda = _dayPeriod(
      localSunrise,
      localSunset,
      weekday: calendarDate.weekday,
      segmentByWeekday: const [4, 3, 2, 1, 7, 6, 5],
      name: 'Yamaganda',
    );
    final gulika = _dayPeriod(
      localSunrise,
      localSunset,
      weekday: calendarDate.weekday,
      segmentByWeekday: const [6, 5, 4, 3, 2, 1, 7],
      name: 'Gulika Kalam',
    );
    final events = !hasSolarDay || nightEnd == null
        ? <PanchangObservance>[]
        : _observances(
            city: city,
            date: calendarDate,
            sunrise: localSunrise,
            madhyahna: madhyahna,
            aparahna: aparahna,
            sunset: localSunset,
            moonrise: moonrise,
            nishita: nishita,
            tithi: tithi,
            monthAmanta: month.name,
            monthPurnimanta: purnimanta,
          );

    return PanchangDay(
      date: calendarDate,
      city: city,
      sunriseUtc: sunrise,
      sunsetUtc: sunset,
      moonriseUtc: moonrise,
      moonsetUtc: moonset,
      sunRashiEndsAtUtc: _nextBoundary(
        localSunrise,
        _siderealSun(localSunrise),
        30,
        _siderealSun,
      ),
      moonRashiEndsAtUtc: _nextBoundary(
        localSunrise,
        _siderealMoon(localSunrise),
        30,
        _siderealMoon,
      ),
      padaEndsAtUtc: _nextBoundary(
        localSunrise,
        _siderealMoon(localSunrise),
        360 / 108,
        _siderealMoon,
      ),
      isAdhikaMonth: month.adhika,
      shakaYear:
          calendarDate.year -
          (calendarDate.month <= 4 && month.index >= 9 ? 1 : 0) -
          78,
      vikramaYear:
          calendarDate.year -
          (calendarDate.month <= 4 && month.index >= 9 ? 1 : 0) +
          57,
      anandadiYoga: _anandadi(localSunrise, calendarDate.weekday),
      lagna: !hasSolarDay || nightEnd == null || city.latitude.abs() >= 66
          ? const []
          : _lagna(localSunrise, nightEnd, city),
      nakshatraPada:
          ((_siderealMoon(localSunrise) % (360 / 27)) / (360 / 108)).floor() +
          1,
      ayanamsa: AstronomyCalculator.lahiriAyanamsa(localSunrise),
      ritu: const [
        'Vasanta',
        'Grishma',
        'Varsha',
        'Sharad',
        'Hemanta',
        'Shishira',
      ][month.index ~/ 2],
      ayana:
          (AstronomyCalculator.sunLongitude(localSunrise) >= 270 ||
              AstronomyCalculator.sunLongitude(localSunrise) < 90)
          ? 'Uttarayana (tropical)'
          : 'Dakshinayana (tropical)',
      hora: !hasSolarDay || nightEnd == null
          ? const []
          : _hora(localSunrise, localSunset, nightEnd, calendarDate.weekday),
      additionalPeriods: !hasSolarDay || nightEnd == null
          ? const []
          : _additionalPeriods(
              localSunrise,
              localSunset,
              nightEnd,
              calendarDate.weekday,
            ),
      specialYogas: _specialYogas(localSunrise, calendarDate.weekday),
      nextSunriseUtc: nightEnd,
      sunRashi: _rashi(
        AstronomyCalculator.normalize(
          AstronomyCalculator.sunLongitude(localSunrise) -
              AstronomyCalculator.apparentLahiriAyanamsa(localSunrise),
        ),
      ),
      moonRashi: _rashi(_siderealMoon(localSunrise)),
      abhijit: !hasSolarDay || calendarDate.weekday == DateTime.wednesday
          ? null
          : PanchangPeriod(
              name: 'Abhijit Muhurta',
              startUtc: madhyahna.subtract(
                localSunset.difference(localSunrise) ~/ 30,
              ),
              endUtc: madhyahna.add(localSunset.difference(localSunrise) ~/ 30),
            ),
      brahmaMuhurta: !hasSolarDay
          ? null
          : PanchangPeriod(
              name: 'Brahma Muhurta',
              startUtc: localSunrise.subtract(const Duration(minutes: 96)),
              endUtc: localSunrise.subtract(const Duration(minutes: 48)),
            ),
      choghadiya: !hasSolarDay || nightEnd == null
          ? const []
          : _choghadiya(
              localSunrise,
              localSunset,
              nightEnd,
              calendarDate.weekday,
            ),
      limbTimeline: Map.unmodifiable({
        for (final entry in {
          'Tithi': _tithiAt,
          'Nakshatra': _nakshatraAt,
          'Yoga': _yogaAt,
          'Karana': _karanaAt,
        }.entries)
          entry.key: _timeline(localSunrise, nightEnd ?? endUtc, entry.value),
      }),
      tithi: tithi,
      nakshatra: nakshatra,
      yoga: yoga,
      karana: karana,
      vara: _varas[calendarDate.weekday],
      amantaMonth: month.name,
      purnimantaMonth: purnimanta,
      rahukala: hasSolarDay ? rahukala : null,
      yamaganda: hasSolarDay ? yamaganda : null,
      gulika: hasSolarDay ? gulika : null,
      observances: events,
    );
  }

  PanchangLimb tithiAt(DateTime utc) => _tithiAt(utc.toUtc());
  PanchangLimb nakshatraAt(DateTime utc) => _nakshatraAt(utc.toUtc());
  DateTime tithiStart(DateTime utc) => _previousBoundary(utc, 12, _elongation);

  DateTime _previousBoundary(
    DateTime utc,
    double width,
    double Function(DateTime) angleAt,
  ) {
    final index = (angleAt(utc) / width).floor();
    var right = utc;
    for (var i = 1; i <= 48; i++) {
      var left = utc.subtract(Duration(hours: i));
      if ((angleAt(left) / width).floor() == index) continue;
      for (var k = 0; k < 24; k++) {
        final middle = left.add(right.difference(left) ~/ 2);
        if ((angleAt(middle) / width).floor() == index) {
          right = middle;
        } else {
          left = middle;
        }
      }
      return right;
    }
    throw StateError('Unable to bracket angular boundary');
  }

  String _anandadi(DateTime instant, int weekday) {
    const names = [
      'Ananda',
      'Kaladanda',
      'Dhumra',
      'Prajapati',
      'Saumya',
      'Dhwanksha',
      'Dhwaja',
      'Srivatsa',
      'Vajra',
      'Mudgara',
      'Chhatra',
      'Mitra',
      'Manasa',
      'Padma',
      'Lumbaka',
      'Utpata',
      'Mrityu',
      'Kana',
      'Siddhi',
      'Shubha',
      'Amrita',
      'Musala',
      'Gada',
      'Matanga',
      'Rakshasa',
      'Chara',
      'Sthira',
      'Vardhamana',
    ];
    final longitude = _siderealMoon(instant);
    final nak = (longitude / (360 / 27)).floor();
    // The traditional 28-star cycle includes Abhijit between Uttara Ashadha
    // and Shravana, occupying 276°40′ through 280°53′20″.
    final extended = longitude >= 276 + 2 / 3 && longitude < 280 + 8 / 9
        ? 21
        : nak >= 21
        ? nak + 1
        : nak;
    const starts = [4, 7, 12, 16, 20, 24, 0];
    return names[(extended - starts[weekday - 1] + 28) % 28];
  }

  List<PanchangPeriod> _lagna(DateTime start, DateTime end, PanchangCity city) {
    double angle(DateTime instant) => AstronomyCalculator.normalize(
      AstronomyCalculator.ascendantLongitude(
            instant,
            city.latitude,
            city.longitude,
          ) -
          AstronomyCalculator.lahiriAyanamsa(instant),
    );
    final result = <PanchangPeriod>[];
    var cursor = start;
    for (var i = 0; i < 16 && cursor.isBefore(end); i++) {
      final value = angle(cursor);
      final boundary = _nextBoundary(cursor, value, 30, angle);
      if (boundary == null || !boundary.isAfter(cursor)) break;
      final stop = boundary.isBefore(end) ? boundary : end;
      result.add(
        PanchangPeriod(name: _rashi(value), startUtc: cursor, endUtc: stop),
      );
      cursor = stop;
    }
    return List.unmodifiable(result);
  }

  List<PanchangPeriod> _hora(
    DateTime sunrise,
    DateTime sunset,
    DateTime nextSunrise,
    int weekday,
  ) {
    const planets = [
      'Saturn',
      'Jupiter',
      'Mars',
      'Sun',
      'Venus',
      'Mercury',
      'Moon',
    ];
    const firstByWeekday = [6, 2, 5, 1, 4, 0, 3];
    final result = <PanchangPeriod>[];
    for (var half = 0; half < 2; half++) {
      final start = half == 0 ? sunrise : sunset;
      final end = half == 0 ? sunset : nextSunrise;
      DateTime boundary(int i) => start.add(
        Duration(
          microseconds: (end.difference(start).inMicroseconds * i / 12).round(),
        ),
      );
      for (var i = 0; i < 12; i++) {
        result.add(
          PanchangPeriod(
            name: planets[(firstByWeekday[weekday - 1] + half * 12 + i) % 7],
            startUtc: boundary(i),
            endUtc: boundary(i + 1),
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  List<PanchangPeriod> _additionalPeriods(
    DateTime sunrise,
    DateTime sunset,
    DateTime nextSunrise,
    int weekday,
  ) {
    final result = <PanchangPeriod>[];
    // Monday-first one-based fifteenths of daylight. Tuesday also has the
    // seventh fifteenth of night. Traditional muhurta table, not clock hours.
    const dur = [
      [9, 12],
      [4],
      [8],
      [6, 12],
      [4, 9],
      [1, 2],
      [14],
    ];
    void addPart(
      String name,
      DateTime start,
      Duration length,
      double offset,
      double width,
      double denominator,
    ) {
      final a = start.add(
        Duration(
          microseconds: (length.inMicroseconds * offset / denominator).round(),
        ),
      );
      final b = start.add(
        Duration(
          microseconds: (length.inMicroseconds * (offset + width) / denominator)
              .round(),
        ),
      );
      if (b.isAfter(sunrise) && a.isBefore(nextSunrise)) {
        result.add(
          PanchangPeriod(
            name: name,
            startUtc: a.isBefore(sunrise) ? sunrise : a,
            endUtc: b.isAfter(nextSunrise) ? nextSunrise : b,
          ),
        );
      }
    }

    for (final part in dur[weekday - 1]) {
      addPart(
        'Dur Muhurta',
        sunrise,
        sunset.difference(sunrise),
        part - 1.0,
        1,
        15,
      );
    }
    if (weekday == DateTime.tuesday) {
      addPart('Dur Muhurta', sunset, nextSunrise.difference(sunset), 6, 1, 15);
    }
    // Ghati offsets within the actual nakshatra duration (60 ghatis).
    const varjya = [
      50,
      24,
      30,
      40,
      14,
      21,
      30,
      20,
      32,
      30,
      20,
      18,
      21,
      20,
      14,
      14,
      10,
      14,
      20,
      24,
      20,
      10,
      10,
      18,
      16,
      24,
      30,
    ];
    const amrita = [
      42,
      48,
      54,
      52,
      38,
      35,
      54,
      44,
      56,
      54,
      44,
      42,
      45,
      44,
      38,
      38,
      34,
      38,
      44,
      48,
      44,
      34,
      34,
      42,
      40,
      48,
      54,
    ];
    var cursor = sunrise;
    for (var count = 0; count < 4 && cursor.isBefore(nextSunrise); count++) {
      final limb = _nakshatraAt(cursor);
      final start = _previousBoundary(cursor, 360 / 27, _siderealMoon);
      final end = limb.endsAtUtc;
      if (end == null) break;
      final duration = end.difference(start);
      addPart(
        'Varjyam',
        start,
        duration,
        varjya[limb.index - 1].toDouble(),
        4,
        60,
      );
      addPart(
        'Amrit Kalam',
        start,
        duration,
        amrita[limb.index - 1].toDouble(),
        4,
        60,
      );
      if (limb.index == 19) addPart('Varjyam', start, duration, 56, 4, 60);
      cursor = end.add(const Duration(seconds: 1));
    }
    result.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return List.unmodifiable(result);
  }

  List<String> _specialYogas(DateTime instant, int weekday) {
    final nak = _nakshatraAt(instant).index;
    final moon = _siderealMoon(instant);
    final tithi = _tithiAt(instant).index;
    final karana = _karanaAt(instant);
    // These labels explicitly describe the sample instant, not all-day windows.
    const sarvartha = [
      [4, 5, 8, 17, 22],
      [1, 9, 26, 3],
      [3, 4, 5, 13, 17],
      [1, 7, 8, 17, 27],
      [1, 7, 17, 22, 27],
      [4, 15, 22],
      [1, 8, 12, 13, 19, 21, 26],
    ];
    final solarNak = (_siderealSun(instant) / (360 / 27)).floor() + 1;
    return List.unmodifiable([
      if (nak == const [5, 1, 17, 8, 27, 4, 13][weekday - 1])
        'Amrita Siddhi Yoga',
      if ([4, 6, 9, 10, 13, 20].contains((nak - solarNak + 27) % 27 + 1))
        'Ravi Yoga',
      if (moon >= 300) 'Panchaka',
      if ([1, 9, 10, 18, 19, 27].contains(nak)) 'Ganda Moola',
      if (moon >= 210 && moon < 240) 'Vinchudo',
      if (karana.name == 'Vishti') 'Bhadra',
      if (sarvartha[weekday - 1].contains(nak)) 'Sarvartha Siddhi Yoga',
      if (weekday == DateTime.sunday && nak == 8) 'Ravi Pushya Yoga',
      if (weekday == DateTime.thursday && nak == 8) 'Guru Pushya Yoga',
      if ([2, 7, 12].contains((tithi - 1) % 15 + 1) &&
          [
            DateTime.sunday,
            DateTime.tuesday,
            DateTime.saturday,
          ].contains(weekday) &&
          [5, 14, 23].contains(nak))
        'Dwipushkara Yoga',
      if ([2, 7, 12].contains((tithi - 1) % 15 + 1) &&
          [
            DateTime.sunday,
            DateTime.tuesday,
            DateTime.saturday,
          ].contains(weekday) &&
          [3, 7, 12, 16, 21, 25].contains(nak))
        'Tripushkara Yoga',
    ]);
  }

  PanchangLimb _tithiAt(DateTime utc) {
    final angle = _elongation(utc);
    final index = (angle / 12).floor().clamp(0, 29);
    final paksha = index < 15 ? 'Shukla' : 'Krishna';
    final nameIndex = index < 15 ? index : index - 15;
    final label = index == 29 ? 'Amavasya' : _tithis[nameIndex];
    final end = _nextBoundary(utc, angle, 12, _elongation);
    return PanchangLimb(
      index: index + 1,
      name: label,
      endsAtUtc: end,
      paksha: paksha,
    );
  }

  PanchangLimb _nakshatraAt(DateTime utc) {
    final angle = _siderealMoon(utc);
    const width = 360 / 27;
    final index = (angle / width).floor().clamp(0, 26);
    return PanchangLimb(
      index: index + 1,
      name: _nakshatras[index],
      endsAtUtc: _nextBoundary(utc, angle, width, _siderealMoon),
    );
  }

  PanchangLimb _yogaAt(DateTime utc) {
    final angle = _yogaAngle(utc);
    const width = 360 / 27;
    final index = (angle / width).floor().clamp(0, 26);
    return PanchangLimb(
      index: index + 1,
      name: _yogas[index],
      endsAtUtc: _nextBoundary(utc, angle, width, _yogaAngle),
    );
  }

  PanchangLimb _karanaAt(DateTime utc) {
    final angle = _elongation(utc);
    final index = (angle / 6).floor().clamp(0, 59);
    final name = switch (index) {
      0 => 'Kimstughna',
      57 => 'Shakuni',
      58 => 'Chatushpada',
      59 => 'Naga',
      _ => _karanaChara[(index - 1) % _karanaChara.length],
    };
    return PanchangLimb(
      index: index + 1,
      name: name,
      endsAtUtc: _nextBoundary(utc, angle, 6, _elongation),
    );
  }

  DateTime? _nextBoundary(
    DateTime start,
    double startAngle,
    double width,
    double Function(DateTime) angleAt,
  ) {
    final startIndex = (startAngle / width).floor();
    final remainder = startAngle - startIndex * width;
    final distance = width - remainder;
    final limit = start.add(Duration(hours: width >= 30 ? 35 * 24 : 40));
    const step = Duration(minutes: 10);
    var low = start;
    DateTime? high;
    for (
      var probe = start.add(step);
      !probe.isAfter(limit);
      probe = probe.add(step)
    ) {
      final progress = AstronomyCalculator.normalize(
        angleAt(probe) - startAngle,
      );
      if (progress >= distance) {
        high = probe;
        break;
      }
      low = probe;
    }
    if (high == null) return null;
    var right = high;
    for (var i = 0; i < 22; i++) {
      final middle = low.add(right.difference(low) ~/ 2);
      final progress = AstronomyCalculator.normalize(
        angleAt(middle) - startAngle,
      );
      if (progress >= distance) {
        right = middle;
      } else {
        low = middle;
      }
    }
    return right;
  }

  double _elongation(DateTime utc) => AstronomyCalculator.normalize(
    AstronomyCalculator.moonLongitude(utc) -
        AstronomyCalculator.sunLongitude(utc),
  );

  double _siderealSun(DateTime utc) => AstronomyCalculator.normalize(
    AstronomyCalculator.sunLongitude(utc) -
        AstronomyCalculator.apparentLahiriAyanamsa(utc),
  );

  double _siderealMoon(DateTime utc) => AstronomyCalculator.normalize(
    AstronomyCalculator.moonLongitude(utc) -
        AstronomyCalculator.apparentLahiriAyanamsa(utc),
  );

  double _yogaAngle(DateTime utc) => AstronomyCalculator.normalize(
    AstronomyCalculator.moonLongitude(utc) +
        AstronomyCalculator.sunLongitude(utc) -
        2 * AstronomyCalculator.apparentLahiriAyanamsa(utc),
  );

  ({int index, String name, bool adhika}) _monthFor(DateTime utc) {
    // Amanta months run from new moon to new moon. Walk back to the preceding
    // conjunction, then apply the traditional one-sign month-name offset.
    final newMoon = _previousNewMoon(utc);
    final siderealSun = AstronomyCalculator.normalize(
      AstronomyCalculator.sunLongitude(newMoon) -
          AstronomyCalculator.apparentLahiriAyanamsa(newMoon),
    );
    // The month follows the sidereal solar sign at the preceding new moon.
    final index = ((siderealSun / 30).floor() + 1) % 12;
    final nextNewMoon = _previousNewMoon(newMoon.add(const Duration(days: 32)));
    final nextSign =
        (AstronomyCalculator.normalize(
                  AstronomyCalculator.sunLongitude(nextNewMoon) -
                      AstronomyCalculator.apparentLahiriAyanamsa(nextNewMoon),
                ) /
                30)
            .floor();
    final adhika = nextSign == (siderealSun / 30).floor();
    return (
      index: index,
      name: '${adhika ? "Adhika " : ""}${_lunarMonths[index]}',
      adhika: adhika,
    );
  }

  DateTime _previousNewMoon(DateTime instant) {
    const step = Duration(hours: 12);
    var later = instant;
    var laterPhase = _elongation(later);
    for (var i = 0; i < 64; i++) {
      final earlier = later.subtract(step);
      final earlierPhase = _elongation(earlier);
      if (earlierPhase > 300 && laterPhase < 60) {
        var left = earlier;
        var right = later;
        for (var j = 0; j < 24; j++) {
          final middle = left.add(right.difference(left) ~/ 2);
          if (_elongation(middle) < 180) {
            right = middle;
          } else {
            left = middle;
          }
        }
        return right;
      }
      later = earlier;
      laterPhase = earlierPhase;
    }
    return instant.subtract(const Duration(days: 30));
  }

  DateTime? _findCrossing(
    DateTime start,
    DateTime end,
    PanchangCity city, {
    required bool moon,
    required double targetAltitude,
    required bool rising,
  }) {
    const step = Duration(minutes: 5);
    double difference(DateTime instant) =>
        AstronomyCalculator.altitudeDegrees(
          instant: instant,
          latitude: city.latitude,
          longitude: city.longitude,
          moon: moon,
        ) -
        targetAltitude;

    var low = start;
    var lowValue = difference(low);
    for (
      var high = start.add(step);
      !high.isAfter(end);
      high = high.add(step)
    ) {
      final highValue = difference(high);
      final crossed = rising
          ? lowValue <= 0 && highValue > 0
          : lowValue >= 0 && highValue < 0;
      if (crossed) {
        var left = low;
        var right = high;
        for (var i = 0; i < 20; i++) {
          final middle = left.add(right.difference(left) ~/ 2);
          final midValue = difference(middle);
          final isAfterCrossing = rising ? midValue > 0 : midValue < 0;
          if (isAfterCrossing) {
            right = middle;
          } else {
            left = middle;
          }
        }
        return right;
      }
      low = high;
      lowValue = highValue;
    }
    return null;
  }

  PanchangPeriod? _dayPeriod(
    DateTime sunrise,
    DateTime sunset, {
    required int weekday,
    required List<int> segmentByWeekday,
    required String name,
  }) {
    if (!sunset.isAfter(sunrise)) return null;
    final segment = sunset.difference(sunrise) ~/ 8;
    final start = sunrise.add(segment * (segmentByWeekday[weekday - 1] - 1));
    return PanchangPeriod(
      name: name,
      startUtc: start,
      endUtc: start.add(segment),
    );
  }

  List<PanchangObservance> _observances({
    required PanchangCity city,
    required DateTime date,
    required DateTime sunrise,
    required DateTime madhyahna,
    required DateTime aparahna,
    required DateTime sunset,
    required DateTime? moonrise,
    required DateTime nishita,
    required PanchangLimb tithi,
    required String monthAmanta,
    required String monthPurnimanta,
  }) {
    final items = <PanchangObservance>[];
    // Krishna-paksha observances are also known by the next Purnimanta label.
    final monthForPaksha = tithi.paksha == 'Krishna'
        ? monthPurnimanta
        : monthAmanta;
    void add(String id, String name, {bool major = false, String note = ''}) {
      if (items.any((item) => item.id == id)) return;
      items.add(
        PanchangObservance(
          id: id,
          name: name,
          ruleSource: 'calculated',
          description: note,
          isMajor: major,
        ),
      );
    }

    switch (tithi.index) {
      case 11:
      case 26:
        add(
          'ekadashi',
          'Ekadashi',
          major: true,
          note:
              'Tithi at local sunrise; fasting and parana follow the app schedule.',
        );
      case 12:
      case 27:
        add('dwadashi', 'Dwadashi');
      case 15:
        add('purnima', 'Purnima', major: true);
      case 30:
        add('amavasya', 'Amavasya', major: true);
      case 4:
        if (tithi.paksha == 'Shukla') {
          add(
            'vinayaka-chaturthi',
            monthAmanta == 'Bhadrapada'
                ? 'Ganesh Chaturthi'
                : 'Vinayaka Chaturthi',
            major: true,
          );
        }
      case 8:
      case 23:
        add('ashtami', 'Ashtami');
      case 9:
      case 24:
        add('navami', 'Navami');
    }

    final middayTithi = _tithiAt(madhyahna);
    final aparahnaTithi = _tithiAt(aparahna);
    final sunsetTithi = _tithiAt(sunset);
    if (sunsetTithi.index == 13 || sunsetTithi.index == 28) {
      add(
        'pradosham',
        'Pradosham',
        major: true,
        note: 'Trayodashi is present at local sunset.',
      );
    }
    final moonriseTithi = moonrise == null ? null : _tithiAt(moonrise);
    if (moonriseTithi?.index == 19) {
      add(
        'sankashti-chaturthi',
        'Sankashti Chaturthi',
        major: true,
        note: 'Krishna Chaturthi is present at local moonrise.',
      );
    }
    final nightTithi = _tithiAt(nishita);
    final isChaturdashiNight = nightTithi.index == 29;
    if (isChaturdashiNight) {
      if (monthAmanta == 'Magha' || monthPurnimanta == 'Phalguna') {
        add(
          'maha-shivaratri',
          'Maha Shivaratri',
          major: true,
          note:
              'Krishna Chaturdashi at Nishita; both common month labels are shown.',
        );
      } else {
        add(
          'masik-shivaratri',
          'Masik Shivaratri',
          major: true,
          note: 'Krishna Chaturdashi at the local night midpoint.',
        );
      }
    }

    // Tithi rules are kept explicit here so each event's paksha, lunar month,
    // and sunrise/sunset/night decision can be reviewed independently.
    final sunriseIndex = tithi.index;
    final sunrisePaksha = tithi.paksha;
    final m = monthForPaksha;
    if (sunrisePaksha == 'Shukla') {
      if (m == 'Chaitra' && sunriseIndex == 1) {
        add('ugadi', 'Ugadi / Gudi Padwa', major: true);
        add('chaitra-navratri', 'Chaitra Navaratri begins', major: true);
      }
      if (m == 'Magha' && sunriseIndex == 5) {
        add('vasant-panchami', 'Vasant Panchami', major: true);
      }
      if (m == 'Chaitra' &&
          middayTithi.index == 9 &&
          middayTithi.paksha == 'Shukla') {
        add('rama-navami', 'Rama Navami', major: true);
      }
      if (m == 'Vaishakha' && sunriseIndex == 3) {
        add('akshaya-tritiya', 'Akshaya Tritiya', major: true);
      }
      if (m == 'Ashadha' && sunriseIndex == 15) {
        add('guru-purnima', 'Guru Purnima', major: true);
      }
      if (m == 'Chaitra' && sunriseIndex == 15) {
        add(
          'hanuman-jayanti',
          'Hanuman Jayanti',
          major: true,
          note: 'Common North Indian Chaitra Purnima observance.',
        );
      }
      if (middayTithi.index == 4 && middayTithi.paksha == 'Shukla') {
        add(
          'vinayaka-chaturthi',
          monthAmanta == 'Bhadrapada'
              ? 'Ganesh Chaturthi'
              : 'Vinayaka Chaturthi',
          major: true,
        );
      }
      if (m == 'Ashvina' && sunriseIndex == 1) {
        add('sharad-navratri', 'Sharad Navaratri begins', major: true);
      }
      if (m == 'Ashvina' &&
          aparahnaTithi.index == 10 &&
          aparahnaTithi.paksha == 'Shukla') {
        add('vijayadashami', 'Vijayadashami', major: true);
      }
      if (m == 'Kartika' && sunriseIndex == 1) {
        add('govardhan-puja', 'Govardhan Puja', major: true);
      }
      if (m == 'Kartika' && sunriseIndex == 2) {
        add('bhai-dooj', 'Bhai Dooj', major: true);
      }
      if (m == 'Kartika' && sunriseIndex == 6) {
        add('chhath-puja', 'Chhath Puja', major: true);
      }
    } else {
      if (m == 'Bhadrapada' &&
          nightTithi.index == 23 &&
          nightTithi.paksha == 'Krishna') {
        add(
          'janmashtami',
          'Krishna Janmashtami',
          major: true,
          note: 'Krishna Ashtami is present at Nishita.',
        );
      }
      if (m == 'Kartika' && sunriseIndex == 19 && moonriseTithi?.index == 19) {
        add(
          'karwa-chauth',
          'Karwa Chauth',
          major: true,
          note: 'Krishna Chaturthi is present at moonrise.',
        );
      }
      if (m == 'Kartika' && sunsetTithi.index == 28) {
        add('dhanteras', 'Dhanteras', major: true);
      }
      if (m == 'Kartika' && sunriseIndex == 29) {
        add('naraka-chaturdashi', 'Naraka Chaturdashi', major: true);
      }
    }
    if (monthAmanta == 'Phalguna' && sunriseIndex == 16) {
      add('holi', 'Holi', major: true);
    }
    if (sunsetTithi.index == 15 && monthForPaksha == 'Phalguna') {
      add(
        'holika-dahan',
        'Holika Dahan',
        major: true,
        note: 'Purnima is present at sunset.',
      );
    }
    if (sunsetTithi.index == 30 && monthPurnimanta == 'Kartika') {
      add(
        'deepavali',
        'Deepavali',
        major: true,
        note: 'Amavasya is present at local sunset.',
      );
    }

    final ingress = _solarIngress(
      startFor(date, city: city),
      endFor(date, city: city),
    );
    if (ingress != null) {
      final sign =
          (AstronomyCalculator.normalize(
                    AstronomyCalculator.sunLongitude(ingress) -
                        AstronomyCalculator.apparentLahiriAyanamsa(ingress),
                  ) /
                  30)
              .floor();
      const signs = [
        'Mesha',
        'Vrishabha',
        'Mithuna',
        'Karka',
        'Simha',
        'Kanya',
        'Tula',
        'Vrischika',
        'Dhanu',
        'Makara',
        'Kumbha',
        'Meena',
      ];
      final signName = signs[sign.clamp(0, 11)];
      final festivalName = sign == 9
          ? 'Makar Sankranti'
          : sign == 0
          ? 'Mesha Sankranti'
          : '$signName Sankranti';
      add(
        'sankranti-$sign',
        festivalName,
        major: true,
        note:
            'Sidereal solar ingress at ${formatPanchangTime(ingress, city, date)}.',
      );
      if (sign == 9) add('pongal', 'Pongal');
    }

    items.sort((a, b) {
      if (a.isMajor != b.isMajor) return a.isMajor ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(items);
  }

  DateTime startFor(
    DateTime date, {
    PanchangCity city = PanchangCity.newDelhi,
  }) => city.midnight(date);
  DateTime endFor(DateTime date, {PanchangCity city = PanchangCity.newDelhi}) =>
      city.midnight(date, dayOffset: 1);

  static String _rashi(double angle) => const [
    'Mesha',
    'Vrishabha',
    'Mithuna',
    'Karka',
    'Simha',
    'Kanya',
    'Tula',
    'Vrischika',
    'Dhanu',
    'Makara',
    'Kumbha',
    'Meena',
  ][(angle / 30).floor() % 12];

  List<PanchangLimb> _timeline(
    DateTime start,
    DateTime end,
    PanchangLimb Function(DateTime) at,
  ) {
    final result = <PanchangLimb>[];
    var cursor = start;
    while (cursor.isBefore(end) && result.length < 8) {
      final limb = at(cursor);
      result.add(limb);
      final next = limb.endsAtUtc;
      if (next == null || !next.isAfter(cursor)) break;
      cursor = next.add(const Duration(seconds: 1));
    }
    return List.unmodifiable(result);
  }

  List<PanchangPeriod> _choghadiya(
    DateTime sunrise,
    DateTime sunset,
    DateTime nextSunrise,
    int weekday,
  ) {
    // Sunday-first starting indices in the repeating planetary sequence.
    const names = ['Udveg', 'Chal', 'Labh', 'Amrit', 'Kaal', 'Shubh', 'Rog'];
    const dayStarts = [0, 3, 6, 2, 5, 1, 4];
    const nightStarts = [0, 2, 4, 6, 1, 3, 5];
    const nightNames = [
      'Shubh',
      'Amrit',
      'Chal',
      'Rog',
      'Kaal',
      'Labh',
      'Udveg',
    ];
    final result = <PanchangPeriod>[];
    for (var night = 0; night < 2; night++) {
      final start = night == 0 ? sunrise : sunset;
      final end = night == 0 ? sunset : nextSunrise;
      final first = (night == 0 ? dayStarts : nightStarts)[weekday % 7];
      DateTime boundary(int i) => start.add(
        Duration(
          microseconds: (end.difference(start).inMicroseconds * i / 8).round(),
        ),
      );
      for (var i = 0; i < 8; i++) {
        final name = (night == 0 ? names : nightNames)[(first + i) % 7];
        result.add(
          PanchangPeriod(
            name: '${night == 0 ? 'Day' : 'Night'} · $name',
            startUtc: boundary(i),
            endUtc: boundary(i + 1),
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  DateTime? _solarIngress(DateTime start, DateTime end) {
    double sidereal(DateTime instant) => AstronomyCalculator.normalize(
      AstronomyCalculator.sunLongitude(instant) -
          AstronomyCalculator.apparentLahiriAyanamsa(instant),
    );
    var low = start;
    var lowAngle = sidereal(low);
    for (
      var high = start.add(const Duration(minutes: 30));
      !high.isAfter(end);
      high = high.add(const Duration(minutes: 30))
    ) {
      final highAngle = sidereal(high);
      if ((highAngle / 30).floor() != (lowAngle / 30).floor() ||
          (lowAngle > 330 && highAngle < 30)) {
        var left = low;
        var right = high;
        final target = ((lowAngle / 30).floor() + 1) * 30;
        for (var i = 0; i < 20; i++) {
          final middle = left.add(right.difference(left) ~/ 2);
          final angle = sidereal(middle);
          final crossed = target >= 360 ? angle < 30 : angle >= target;
          if (crossed) {
            right = middle;
          } else {
            left = middle;
          }
        }
        return right;
      }
      low = high;
      lowAngle = highAngle;
    }
    return null;
  }
}
