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
      rising: true,
    );
    var sunset = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: false,
      rising: false,
    );
    if (sunrise != null && sunset != null && sunset.isBefore(sunrise)) {
      sunset = _findCrossing(
        sunrise,
        city.midnight(calendarDate, dayOffset: 2),
        city,
        moon: false,
        rising: false,
      );
    }
    final moonrise = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: true,
      rising: true,
    );
    final moonset = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: true,
      rising: false,
    );
    final hasSolarDay =
        sunrise != null && sunset != null && sunset.isAfter(sunrise);
    final localSunrise = sunrise ?? city.dateAtHour(calendarDate, 6);
    final localSunset = sunset ?? city.dateAtHour(calendarDate, 18);
    final madhyahna = localSunrise.add(
      localSunset.difference(localSunrise) ~/ 2,
    );
    final nightEnd = _findCrossing(
      localSunset,
      city.midnight(calendarDate, dayOffset: 2),
      city,
      moon: false,
      rising: true,
    );

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
            sunset: localSunset,
            tithi: tithi,
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
    required bool rising,
  }) {
    const step = Duration(minutes: 5);
    // Apparent upper limb on a sea-level horizon: geometric altitude of the
    // centre equals -(horizon refraction + actual semidiameter).
    double difference(DateTime instant) =>
        AstronomyCalculator.altitudeDegrees(
          instant: instant,
          latitude: city.latitude,
          longitude: city.longitude,
          moon: moon,
        ) +
        AstronomyCalculator.horizonRefraction +
        AstronomyCalculator.semidiameterDegrees(instant, moon: moon);

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
    required DateTime sunset,
    required PanchangLimb tithi,
  }) {
    final items = <PanchangObservance>[];
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

    final days = _SolarDays(this, city);
    final nextSunrise = days.of(date.add(const Duration(days: 1))).sunrise;
    final tomorrow = nextSunrise == null ? null : _tithiAt(nextSunrise).index;

    // Occurrences of tithi [index] (1-30) that can be observed on [date]:
    // the one current at sunrise, its neighbours and the next sunrise's.
    bool near(int index) {
      bool same(int a, int b) => (a - b) % 30 == 0;
      return same(index, tithi.index) ||
          same(index, tithi.index + 1) ||
          same(index, tithi.index - 1) ||
          (tomorrow != null &&
              (same(index, tomorrow) || same(index, tomorrow + 1)));
    }

    _Occurrence? occurrence(int index) =>
        near(index) ? _occurrence(index, date, sunrise, tithi, days) : null;

    bool observed(
      int index,
      _Kala kala, {
      String? month,
      _Tie tie = _Tie.longest,
    }) {
      final found = occurrence(index);
      if (found == null) return false;
      if (month != null && found.month != month) return false;
      return _sameDate(found.observedOn(kala, tie, days, city), date);
    }

    // Monthly observances.
    if (_smartaEkadashi(date, days)) {
      add(
        'ekadashi',
        'Ekadashi',
        major: true,
        note:
            'Smarta fasting day for this location (Drik rules); Gaudiya days are in the Ekadashi tab.',
      );
    }
    for (final index in const [12, 27]) {
      if (tithi.index == index) add('dwadashi', 'Dwadashi');
    }
    if (observed(15, _Kala.sunrise)) add('purnima', 'Purnima', major: true);
    if (observed(30, _Kala.sunrise)) add('amavasya', 'Amavasya', major: true);
    for (final index in const [8, 23]) {
      if (tithi.index == index) add('ashtami', 'Ashtami');
    }
    for (final index in const [9, 24]) {
      if (tithi.index == index) add('navami', 'Navami');
    }
    final chaturthi = occurrence(4);
    if (chaturthi != null &&
        _sameDate(
          chaturthi.observedOn(_Kala.madhyahna, _Tie.longest, days, city),
          date,
        )) {
      final annual = chaturthi.month == 'Bhadrapada';
      add(
        'vinayaka-chaturthi',
        annual ? 'Ganesh Chaturthi' : 'Vinayaka Chaturthi (monthly)',
        major: true,
        note: 'Shukla Chaturthi during Madhyahna (the third fifth of the day).',
      );
    }
    for (final index in const [13, 28]) {
      if (observed(index, _Kala.pradosh)) {
        add(
          'pradosham',
          'Pradosham',
          major: true,
          note: 'Trayodashi during Pradosh (the first fifth of the night).',
        );
      }
    }
    if (observed(19, _Kala.moonrise, tie: _Tie.first)) {
      add(
        'sankashti-chaturthi',
        'Sankashti Chaturthi',
        major: true,
        note: 'Krishna Chaturthi is present at local moonrise.',
      );
    }
    final chaturdashi = occurrence(29);
    if (chaturdashi != null &&
        _sameDate(
          chaturdashi.observedOn(_Kala.nishita, _Tie.longest, days, city),
          date,
        )) {
      if (chaturdashi.month == 'Magha') {
        add(
          'maha-shivaratri',
          'Maha Shivaratri',
          major: true,
          note:
              'Krishna Chaturdashi at Nishita (Magha Amanta, Phalguna Purnimanta).',
        );
      } else {
        add(
          'masik-shivaratri',
          'Masik Shivaratri',
          major: true,
          note:
              'Krishna Chaturdashi at Nishita, the eighth fifteenth of the night.',
        );
      }
    }

    // Annual festivals. Months are Amanta; each tithi keeps its own month,
    // so festivals never move into an Adhika month or the wrong lunation.
    if (observed(1, _Kala.sunrise, month: 'Chaitra')) {
      add('ugadi', 'Ugadi / Gudi Padwa', major: true);
      add('chaitra-navratri', 'Chaitra Navaratri begins', major: true);
    }
    if (observed(5, _Kala.purvahna, month: 'Magha')) {
      add('vasant-panchami', 'Vasant Panchami', major: true);
    }
    if (observed(9, _Kala.madhyahna, month: 'Chaitra')) {
      add('rama-navami', 'Rama Navami', major: true);
    }
    if (observed(15, _Kala.sunrise, month: 'Chaitra')) {
      add(
        'hanuman-jayanti',
        'Hanuman Jayanti',
        major: true,
        note: 'Common North Indian Chaitra Purnima observance.',
      );
    }
    if (observed(3, _Kala.akshaya, month: 'Vaishakha')) {
      add('akshaya-tritiya', 'Akshaya Tritiya', major: true);
    }
    if (observed(15, _Kala.sunrise, month: 'Ashadha')) {
      add('guru-purnima', 'Guru Purnima', major: true);
    }
    final ashtami = occurrence(23);
    if (ashtami != null &&
        ashtami.month == 'Shravana' &&
        _sameDate(_janmashtami(ashtami, days, city), date)) {
      add(
        'janmashtami',
        'Krishna Janmashtami',
        major: true,
        note:
            'Smarta: Krishna Ashtami at Nishita, preferring the night with Rohini.',
      );
    }
    if (observed(1, _Kala.sunrise, month: 'Ashvina')) {
      add('sharad-navratri', 'Sharad Navaratri begins', major: true);
    }
    if (observed(10, _Kala.aparahna, month: 'Ashvina')) {
      add('vijayadashami', 'Vijayadashami', major: true);
    }
    if (observed(19, _Kala.moonrise, month: 'Ashvina', tie: _Tie.first)) {
      add(
        'karwa-chauth',
        'Karwa Chauth',
        major: true,
        note: 'Krishna Chaturthi is present at moonrise.',
      );
    }
    if (observed(28, _Kala.pradosh, month: 'Ashvina')) {
      add('dhanteras', 'Dhanteras', major: true);
    }
    if (observed(29, _Kala.arunodaya, month: 'Ashvina')) {
      add('naraka-chaturdashi', 'Naraka Chaturdashi', major: true);
    }
    if (observed(30, _Kala.pradosh, month: 'Ashvina')) {
      add(
        'deepavali',
        'Deepavali',
        major: true,
        note: 'Amavasya during Pradosh (Lakshmi Puja).',
      );
    }
    if (observed(1, _Kala.pratah, month: 'Kartika')) {
      add('govardhan-puja', 'Govardhan Puja', major: true);
    }
    if (observed(2, _Kala.aparahna, month: 'Kartika')) {
      add('bhai-dooj', 'Bhai Dooj', major: true);
    }
    if (observed(6, _Kala.sunset, month: 'Kartika', tie: _Tie.first)) {
      add('chhath-puja', 'Chhath Puja', major: true);
    }
    if (observed(15, _Kala.pradosh, month: 'Phalguna')) {
      add(
        'holika-dahan',
        'Holika Dahan',
        major: true,
        note: 'Purnima during Pradosh. Bhadra is not evaluated.',
      );
    }
    final holika = _holikaDate(
      date.subtract(const Duration(days: 1)),
      city,
      days,
    );
    if (holika != null &&
        _sameDate(holika, date.subtract(const Duration(days: 1)))) {
      add('holi', 'Holi', major: true, note: 'The day after Holika Dahan.');
    }

    // Solar ingress: the Sankranti moment on its civil date. Makar Sankranti
    // and Pongal move to the next day when the ingress is after sunset.
    final start = startFor(date, city: city), end = endFor(date, city: city);
    final ingress = _solarIngress(start, end);
    if (ingress != null) {
      final sign = _siderealSign(ingress);
      if (sign != 9) {
        add(
          'sankranti-$sign',
          sign == 0 ? 'Mesha Sankranti' : '${_signs[sign]} Sankranti',
          major: true,
          note:
              'Sidereal solar ingress at ${formatPanchangTime(ingress, city, date)}.',
        );
      } else if (ingress.isBefore(sunset)) {
        _addMakar(add, ingress, city, date);
      }
    }
    final previous = date.subtract(const Duration(days: 1));
    final yesterdayIngress = _solarIngress(
      startFor(previous, city: city),
      startFor(date, city: city),
    );
    if (yesterdayIngress != null && _siderealSign(yesterdayIngress) == 9) {
      final previousSunset = days.of(previous).sunset;
      if (previousSunset != null &&
          !yesterdayIngress.isBefore(previousSunset)) {
        _addMakar(add, yesterdayIngress, city, date);
      }
    }

    items.sort((a, b) {
      if (a.isMajor != b.isMajor) return a.isMajor ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(items);
  }

  static const _signs = [
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

  int _siderealSign(DateTime instant) =>
      (AstronomyCalculator.normalize(
                AstronomyCalculator.sunLongitude(instant) -
                    AstronomyCalculator.apparentLahiriAyanamsa(instant),
              ) /
              30)
          .floor()
          .clamp(0, 11);

  void _addMakar(
    void Function(String, String, {bool major, String note}) add,
    DateTime ingress,
    PanchangCity city,
    DateTime date,
  ) {
    add(
      'sankranti-9',
      'Makar Sankranti',
      major: true,
      note:
          'Sidereal ingress into Makara at ${formatPanchangTime(ingress, city, date)}; after sunset it is observed the next day.',
    );
    add('pongal', 'Pongal');
  }

  static bool _sameDate(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  /// The occurrence of tithi [index] (1-30) closest to [date]'s sunrise.
  _Occurrence? _occurrence(
    int index,
    DateTime date,
    DateTime sunrise,
    PanchangLimb current,
    _SolarDays days,
  ) {
    DateTime probe;
    if (current.index == index) {
      probe = sunrise;
    } else if ((index - current.index) % 30 == 1) {
      probe = current.endsAtUtc!.add(const Duration(seconds: 1));
    } else if ((current.index - index) % 30 == 1) {
      probe = tithiStart(sunrise).subtract(const Duration(seconds: 1));
    } else {
      final next = days.of(date.add(const Duration(days: 1))).sunrise;
      if (next == null) return null;
      final limb = _tithiAt(next);
      probe = limb.index == index
          ? next
          : limb.endsAtUtc!.add(const Duration(seconds: 1));
    }
    final limb = _tithiAt(probe);
    if (limb.index != index || limb.endsAtUtc == null) return null;
    final start = tithiStart(probe);
    final end = limb.endsAtUtc!;
    final middle = start.add(end.difference(start) ~/ 2);
    final month = _monthFor(middle);
    return _Occurrence(
      start: start,
      end: end,
      month: month.adhika
          ? 'Adhika ${_lunarMonths[month.index]}'
          : _lunarMonths[month.index],
    );
  }

  /// Smarta Janmashtami: Krishna Ashtami at Nishita. If Rohini is not at
  /// that midnight but is at the next one, while Ashtami still prevails at
  /// that day's sunrise, the next day is preferred (Rohini-yukta Ashtami).
  DateTime? _janmashtami(
    _Occurrence ashtami,
    _SolarDays days,
    PanchangCity city,
  ) {
    final chosen = ashtami.observedOn(_Kala.nishita, _Tie.longest, days, city);
    if (chosen == null) return null;
    bool rohiniAtNishita(DateTime day) {
      final window = days.window(day, _Kala.nishita);
      if (window == null) return false;
      final middle = window.$1.add(window.$2.difference(window.$1) ~/ 2);
      return _nakshatraAt(middle).index == 4;
    }

    final next = chosen.add(const Duration(days: 1));
    final nextSunrise = days.of(next).sunrise;
    if (!rohiniAtNishita(chosen) &&
        rohiniAtNishita(next) &&
        nextSunrise != null &&
        nextSunrise.isBefore(ashtami.end)) {
      return next;
    }
    return chosen;
  }

  DateTime? _holikaDate(DateTime date, PanchangCity city, _SolarDays days) {
    final sunrise = days.of(date).sunrise;
    if (sunrise == null) return null;
    final current = _tithiAt(sunrise);
    if (![14, 15, 16].contains(current.index)) return null;
    final found = _occurrence(15, date, sunrise, current, days);
    if (found == null || found.month != 'Phalguna') return null;
    return found.observedOn(_Kala.pradosh, _Tie.longest, days, city);
  }

  bool _smartaEkadashi(DateTime date, _SolarDays days) {
    int? fortnight(int offset) {
      final sunrise = days.of(date.add(Duration(days: offset))).sunrise;
      return sunrise == null ? null : (_tithiAt(sunrise).index - 1) % 15 + 1;
    }

    final t = fortnight(0);
    if (t != 10 && t != 11) return false;
    final p = fortnight(-1), n = fortnight(1), nn = fortnight(2);
    if (p == null || n == null || nn == null) return false;
    if (t == 11 && p != 11) return n == 11 ? nn != 12 : n == 12;
    if (t == 11 && p == 11) return n == 12;
    return n == 12 || (n == 11 && nn == 13);
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

/// Time windows (kala) used by festival rules; fifths of daylight follow the
/// five-part day (Pratah, Sangava, Madhyahna, Aparahna, Sayahna).
enum _Kala {
  sunrise,
  sunset,
  moonrise,
  purvahna,
  pratah,
  madhyahna,
  aparahna,
  pradosh,
  nishita,
  arunodaya,
  akshaya,
}

/// When a tithi covers its window on two days: the longer coverage, or the
/// first day.
enum _Tie { longest, first }

class _Solar {
  const _Solar(this.sunrise, this.sunset, this.nextSunrise, this.moonrise);
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? nextSunrise;
  final DateTime? moonrise;
}

/// Lazily computed sunrise/sunset/moonrise for neighbouring civil days.
class _SolarDays {
  _SolarDays(this.engine, this.city);
  final PanchangEngine engine;
  final PanchangCity city;
  final _cache = <int, _Solar>{};

  _Solar of(DateTime date) {
    final key = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    return _cache[key] ??= _compute(
      DateTime.utc(date.year, date.month, date.day),
    );
  }

  _Solar _compute(DateTime date) {
    final start = engine.startFor(date, city: city);
    final end = engine.endFor(date, city: city);
    final sunrise = engine._findCrossing(
      start,
      end,
      city,
      moon: false,
      rising: true,
    );
    DateTime? sunset;
    if (sunrise != null) {
      sunset = engine._findCrossing(
        sunrise,
        city.midnight(date, dayOffset: 2),
        city,
        moon: false,
        rising: false,
      );
    }
    final nextSunrise = sunset == null
        ? null
        : engine._findCrossing(
            sunset,
            city.midnight(date, dayOffset: 2),
            city,
            moon: false,
            rising: true,
          );
    final moonrise = engine._findCrossing(
      start,
      end,
      city,
      moon: true,
      rising: true,
    );
    return _Solar(sunrise, sunset, nextSunrise, moonrise);
  }

  /// [start, end] of the window on civil [date]; instants have start == end.
  (DateTime, DateTime)? window(DateTime date, _Kala kala) {
    final day = of(date);
    final a = day.sunrise, b = day.sunset, n = day.nextSunrise;
    if (a == null || b == null || n == null) return null;
    final dayLength = b.difference(a), night = n.difference(b);
    DateTime at(DateTime from, Duration length, double fraction) => from.add(
      Duration(microseconds: (length.inMicroseconds * fraction).round()),
    );
    return switch (kala) {
      _Kala.sunrise => (a, a),
      _Kala.sunset => (b, b),
      _Kala.moonrise =>
        day.moonrise == null ? null : (day.moonrise!, day.moonrise!),
      _Kala.purvahna => (a, at(a, dayLength, .5)),
      _Kala.pratah || _Kala.akshaya => (a, at(a, dayLength, .2)),
      _Kala.madhyahna => (at(a, dayLength, .4), at(a, dayLength, .6)),
      _Kala.aparahna => (at(a, dayLength, .6), at(a, dayLength, .8)),
      _Kala.pradosh => (b, at(b, night, .2)),
      _Kala.nishita => (at(b, night, 7 / 15), at(b, night, 8 / 15)),
      _Kala.arunodaya => (a.subtract(const Duration(minutes: 96)), a),
    };
  }
}

class _Occurrence {
  const _Occurrence({
    required this.start,
    required this.end,
    required this.month,
  });
  final DateTime start;
  final DateTime end;
  final String month;

  bool _covers(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  Duration _overlap((DateTime, DateTime) window) {
    final from = window.$1.isAfter(start) ? window.$1 : start;
    final to = window.$2.isBefore(end) ? window.$2 : end;
    return to.isAfter(from) ? to.difference(from) : Duration.zero;
  }

  /// The civil date on which this tithi is observed for [kala].
  DateTime? observedOn(
    _Kala kala,
    _Tie tie,
    _SolarDays days,
    PanchangCity city,
  ) {
    final first = city.wallClock(start.subtract(const Duration(days: 1)));
    final last = city.wallClock(end.add(const Duration(days: 1)));
    final candidates = <DateTime>[];
    for (
      var day = DateTime.utc(first.year, first.month, first.day);
      !day.isAfter(DateTime.utc(last.year, last.month, last.day));
      day = day.add(const Duration(days: 1))
    ) {
      candidates.add(day);
    }
    final instant =
        kala == _Kala.sunrise || kala == _Kala.sunset || kala == _Kala.moonrise;
    if (kala == _Kala.akshaya) {
      // Udaya tithi if it lasts through Pratahkala; otherwise the previous
      // day, when the tithi began during that forenoon.
      for (final day in candidates) {
        final window = days.window(day, _Kala.pratah);
        if (window != null && _covers(window.$1)) {
          if (!end.isBefore(window.$2)) return day;
          final previous = day.subtract(const Duration(days: 1));
          final forenoon = days.window(previous, _Kala.purvahna);
          return forenoon != null && _overlap(forenoon) > Duration.zero
              ? previous
              : day;
        }
      }
    }
    DateTime? best;
    var bestOverlap = Duration.zero;
    for (final day in candidates) {
      final window = days.window(
        day,
        kala == _Kala.akshaya ? _Kala.purvahna : kala,
      );
      if (window == null) continue;
      if (instant) {
        if (_covers(window.$1)) return day;
        continue;
      }
      final overlap = _overlap(window);
      if (overlap <= Duration.zero) continue;
      if (tie == _Tie.first) return day;
      if (overlap > bestOverlap) {
        best = day;
        bestOverlap = overlap;
      }
    }
    if (best != null) return best;
    // Tithi touches no window (kshaya): the civil day on which it begins,
    // counted from sunrise.
    for (final day in candidates) {
      final today = days.of(day),
          next = days.of(day.add(const Duration(days: 1)));
      final a = today.sunrise, n = next.sunrise;
      if (a != null && n != null && !start.isBefore(a) && start.isBefore(n)) {
        return day;
      }
    }
    return null;
  }
}
