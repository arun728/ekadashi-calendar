import 'astronomy_calculator.dart';
import 'panchang_city.dart';
import 'panchang_models.dart';

/// Offline Panchang calculator for Indian civil dates and a fixed IST clock.
/// The argument is a calendar date; its fields are used as-is, regardless of
/// the host device timezone.
class PanchangEngine {
  const PanchangEngine();

  static const _istOffset = Duration(hours: 5, minutes: 30);
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
    final calendarDate = DateTime.utc(date.year, date.month, date.day);
    final startUtc = calendarDate.subtract(_istOffset);
    final endUtc = startUtc.add(const Duration(days: 1));
    final sunrise = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: false,
      targetAltitude: -0.833,
      rising: true,
    );
    final sunset = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: false,
      targetAltitude: -0.833,
      rising: false,
    );
    final moonrise = _findCrossing(
      startUtc,
      endUtc,
      city,
      moon: true,
      targetAltitude: 0.125,
      rising: true,
    );
    final localSunrise = sunrise ?? startUtc.add(const Duration(hours: 6));
    final localSunset = sunset ?? startUtc.add(const Duration(hours: 18));
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
      endUtc.add(const Duration(hours: 12)),
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
    final purnimantaIndex = tithi.paksha == 'Krishna'
        ? (month.index + 1) % 12
        : month.index;
    final purnimanta = _lunarMonths[purnimantaIndex];
    final rahukala = _dayPeriod(
      localSunrise,
      localSunset,
      weekday: calendarDate.weekday,
      segmentByWeekday: const [8, 2, 7, 5, 6, 4, 3],
      name: 'Rahu Kalam',
    );
    final yamaganda = _dayPeriod(
      localSunrise,
      localSunset,
      weekday: calendarDate.weekday,
      segmentByWeekday: const [5, 4, 3, 2, 1, 7, 6],
      name: 'Yamaganda',
    );
    final gulika = _dayPeriod(
      localSunrise,
      localSunset,
      weekday: calendarDate.weekday,
      segmentByWeekday: const [7, 6, 5, 4, 3, 2, 1],
      name: 'Gulika Kalam',
    );
    final events = _observances(
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
      tithi: tithi,
      nakshatra: nakshatra,
      yoga: yoga,
      karana: karana,
      vara: _varas[calendarDate.weekday],
      amantaMonth: month.name,
      purnimantaMonth: purnimanta,
      rahukala: rahukala,
      yamaganda: yamaganda,
      gulika: gulika,
      observances: events,
    );
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
    final limit = start.add(const Duration(hours: 40));
    var low = start;
    DateTime? high;
    for (
      var probe = start.add(const Duration(minutes: 10));
      !probe.isAfter(limit);
      probe = probe.add(const Duration(minutes: 10))
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

  double _siderealMoon(DateTime utc) => AstronomyCalculator.normalize(
    AstronomyCalculator.moonLongitude(utc) -
        AstronomyCalculator.lahiriAyanamsa(utc),
  );

  double _yogaAngle(DateTime utc) => AstronomyCalculator.normalize(
    AstronomyCalculator.moonLongitude(utc) +
        AstronomyCalculator.sunLongitude(utc) -
        2 * AstronomyCalculator.lahiriAyanamsa(utc),
  );

  ({int index, String name}) _monthFor(DateTime utc) {
    // Amanta months run from new moon to new moon. Walk back to the preceding
    // conjunction, then apply the traditional one-sign month-name offset.
    final newMoon = _previousNewMoon(utc);
    final siderealSun = AstronomyCalculator.normalize(
      AstronomyCalculator.sunLongitude(newMoon) -
          AstronomyCalculator.lahiriAyanamsa(newMoon),
    );
    // The month follows the sidereal solar sign at the preceding new moon.
    final index = ((siderealSun / 30).floor() + 1) % 12;
    return (index: index, name: _lunarMonths[index]);
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

    final ingress = _solarIngress(startFor(date), endFor(date));
    if (ingress != null) {
      final sign =
          (AstronomyCalculator.normalize(
                    AstronomyCalculator.sunLongitude(ingress) -
                        AstronomyCalculator.lahiriAyanamsa(ingress),
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
        note: 'Sidereal solar ingress at ${formatIstTime(ingress)} IST.',
      );
      if (sign == 9) add('pongal', 'Pongal');
    }

    items.sort((a, b) {
      if (a.isMajor != b.isMajor) return a.isMajor ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return List.unmodifiable(items);
  }

  DateTime startFor(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).subtract(_istOffset);
  DateTime endFor(DateTime date) => startFor(date).add(const Duration(days: 1));

  DateTime? _solarIngress(DateTime start, DateTime end) {
    double sidereal(DateTime instant) => AstronomyCalculator.normalize(
      AstronomyCalculator.sunLongitude(instant) -
          AstronomyCalculator.lahiriAyanamsa(instant),
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
