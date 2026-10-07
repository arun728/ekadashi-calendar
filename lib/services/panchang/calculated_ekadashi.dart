import 'panchang_city.dart';
import 'panchang_engine.dart';
import 'panchang_models.dart';

enum EkadashiTradition {
  smarta('Smarta'),
  gaudiya('Vaishnava · Gaudiya/ISKCON');

  const EkadashiTradition(this.label);
  final String label;
}

/// Rule inputs are separated from astronomy to test rare tithi configurations.
class EkadashiSample {
  const EkadashiSample({
    required this.date,
    required this.sunrise,
    required this.sunset,
    required this.tithi,
    required this.arunodayaTithi,
    required this.sunsetTithi,
    required this.nakshatra,
  });
  final DateTime date;
  final DateTime? sunrise;
  final DateTime? sunset;
  final int tithi;
  final int arunodayaTithi;
  final int sunsetTithi;
  final int nakshatra;
  int get fortnightTithi => (tithi - 1) % 15 + 1;
  int get arunodaya => (arunodayaTithi - 1) % 15 + 1;
}

/// Current-location profiles; astronomical apparent upper-limb sunrise.
/// Gaudiya decision table was cross-reviewed with the MIT-licensed GCAL
/// reference implementation. See docs/PANCHANG_RESEARCH.md and notices.
class EkadashiRules {
  static String? select(
    List<EkadashiSample> days,
    int index,
    EkadashiTradition tradition,
  ) {
    if (index < 1 || index + 1 >= days.length) return null;
    final previous = days[index - 1];
    final today = days[index];
    final next = days[index + 1];
    if ([
      previous,
      today,
      next,
    ].any((d) => d.sunrise == null || d.sunset == null)) {
      return null;
    }
    final t = today.fortnightTithi;
    if (tradition == EkadashiTradition.smarta) {
      return _smarta(days, index);
    }
    final mahadvadashi = _mahadvadashi(days, index);
    if (mahadvadashi != null) return mahadvadashi;
    if (t != 11 || today.arunodaya < 11) return null;
    final repeated = previous.fortnightTithi == 11 && previous.arunodaya == 11;
    if (next.fortnightTithi == 13) {
      return repeated ? 'Unmilani-Trisprisha' : 'Trisprisha';
    }
    if (repeated) return 'Unmilani';
    if (next.fortnightTithi == 11 || _mahadvadashi(days, index + 1) != null) {
      return null;
    }
    return 'Shuddha Ekadashi';
  }

  /// Smarta householder rules, as published by Drik Panchang (validated
  /// against all 24 Delhi 2027 dates; see docs/PANCHANG_ACCURACY.md):
  /// - one Ekadashi sunrise followed by Dwadashi: that day;
  /// - Ekadashi at two sunrises: the second day when Dwadashi also reaches
  ///   the next sunrise, otherwise the first day;
  /// - Ekadashi touching no sunrise, or Dwadashi touching no sunrise after
  ///   the Ekadashi day: the Dashami day, so that Parana falls in Dwadashi.
  static String? _smarta(List<EkadashiSample> days, int i) {
    // A decision needs sunrises from two days before to three days after
    // (and sunsets around the day); otherwise none is offered.
    if (i < 2 || i + 3 >= days.length) return null;
    for (var k = i - 2; k <= i + 3; k++) {
      if (days[k].sunrise == null) return null;
    }
    final p = days[i - 1].fortnightTithi;
    final t = days[i].fortnightTithi;
    final n = days[i + 1].fortnightTithi;
    final nn = days[i + 2].fortnightTithi;
    if (t == 11 && p != 11) {
      if (n == 11) return nn == 12 ? null : 'Sunrise Ekadashi (first of two)';
      return n == 12 ? 'Sunrise Ekadashi' : null;
    }
    if (t == 11 && p == 11) {
      return n == 12 ? 'Ekadashi and Dwadashi both extended' : null;
    }
    if (t == 10) {
      if (n == 12) return 'Kshaya Ekadashi: fast on Dashami day';
      if (n == 11 && nn == 13) return 'Kshaya Dwadashi: fast on Dashami day';
    }
    return null;
  }

  static String? _mahadvadashi(List<EkadashiSample> days, int i) {
    if (i < 1 || i + 1 >= days.length) return null;
    final p = days[i - 1], t = days[i], n = days[i + 1];
    if (p.fortnightTithi == 12 || t.fortnightTithi != 12) return null;
    if (t.tithi == 12 && t.sunsetTithi == 12 && t.nakshatra == n.nakshatra) {
      final name = const {
        7: 'Jaya',
        4: 'Jayanti',
        8: 'Papanashini',
        22: 'Vijaya',
      }[t.nakshatra];
      if (name != null) return name;
    }
    if (n.fortnightTithi == 12 && p.fortnightTithi == 11 && p.arunodaya == 11) {
      return 'Vyanjuli';
    }
    for (var j = i + 1; j < days.length && j < i + 8; j++) {
      if (days[j].sunrise != null &&
          days[j - 1].sunrise != null &&
          days[j].fortnightTithi == 15 &&
          days[j].tithi == days[j - 1].tithi) {
        return 'Pakshavardhini';
      }
    }
    if (p.arunodaya < 11) return 'Viddha / shifted to Dwadashi';
    return null;
  }
}

class CalculatedEkadashi {
  const CalculatedEkadashi({
    required this.date,
    required this.name,
    required this.tradition,
    required this.rule,
    required this.city,
    required this.fastStartsUtc,
    required this.paranaDate,
    required this.paranaStartUtc,
    required this.paranaEndUtc,
    required this.paranaReason,
    required this.hariVasaraEndUtc,
    required this.tithiStartUtc,
    required this.tithiEndUtc,
    required this.nearBoundary,
  });
  final DateTime date;
  final String name;
  final EkadashiTradition tradition;
  final String rule;
  final PanchangCity city;
  final DateTime fastStartsUtc;
  final DateTime paranaDate;
  final DateTime? paranaStartUtc;
  final DateTime? paranaEndUtc;
  final String paranaReason;
  final DateTime? hariVasaraEndUtc;
  final DateTime tithiStartUtc;
  final DateTime tithiEndUtc;
  final bool nearBoundary;
  static const ruleVersion = 'current-location-v2';
  // Candidate data deliberately does not implement the published Ekadashi
  // model: no accidental replacement of reminders, tracker IDs or history.
}

class CalculatedEkadashiEngine {
  const CalculatedEkadashiEngine({this.engine = const PanchangEngine()});
  final PanchangEngine engine;

  List<CalculatedEkadashi> calculate(
    DateTime start,
    int count,
    PanchangCity city,
    EkadashiTradition tradition,
  ) {
    if (count < 1 || count > 366) {
      throw ArgumentError('Choose 1–366 civil days');
    }
    final first = DateTime.utc(start.year, start.month, start.day);
    final days = <PanchangDay>[];
    final samples = <EkadashiSample>[];
    // Neighbours across month/year boundaries and the next full/new moon are
    // necessary for repeated/skipped tithi and Pakshavardhini decisions.
    for (var offset = -2; offset < count + 9; offset++) {
      final day = engine.calculate(
        first.add(Duration(days: offset)),
        city: city,
      );
      days.add(day);
      samples.add(
        EkadashiSample(
          date: day.date,
          sunrise: day.sunriseUtc,
          sunset: day.sunsetUtc,
          tithi: day.tithi.index,
          arunodayaTithi: day.sunriseUtc == null
              ? 0
              : engine
                    .tithiAt(
                      day.sunriseUtc!.subtract(const Duration(minutes: 96)),
                    )
                    .index,
          sunsetTithi: day.sunsetUtc == null
              ? 0
              : engine.tithiAt(day.sunsetUtc!).index,
          nakshatra: day.nakshatra.index,
        ),
      );
    }
    final result = <CalculatedEkadashi>[];
    for (var i = 2; i < count + 2; i++) {
      final rule = EkadashiRules.select(samples, i, tradition);
      if (rule == null) continue;
      final day = days[i], next = days[i + 1];
      final sunrise = day.sunriseUtc!;
      // Locate the actual Ekadashi interval: later the same day when the
      // fast is on the Dashami day, earlier when fasting on Dwadashi.
      final forward = samples[i].fortnightTithi == 10;
      var probe = sunrise;
      for (
        var hours = 0;
        hours < 72 && (engine.tithiAt(probe).index - 1) % 15 + 1 != 11;
        hours++
      ) {
        probe = probe.add(Duration(hours: forward ? 1 : -1));
      }
      final ekadashi = engine.tithiAt(probe);
      if ((ekadashi.index - 1) % 15 + 1 != 11) continue;
      final tithiStart = engine.tithiStart(probe);
      final tithiEnd = ekadashi.endsAtUtc!;
      final dwadashi = engine.tithiAt(tithiEnd.add(const Duration(seconds: 1)));
      final dwadashiEnd = dwadashi.endsAtUtc!;
      final hariVasara = tithiEnd.add(dwadashiEnd.difference(tithiEnd) ~/ 4);
      final parana = tradition == EkadashiTradition.smarta
          ? _smartaParana(next, tithiEnd, dwadashiEnd)
          : _parana(day, next, tradition, rule, hariVasara);
      final arunodaya = sunrise.subtract(const Duration(minutes: 96));
      final nearBoundary =
          [day.nakshatra, next.nakshatra].any(
            (limb) =>
                limb.endsAtUtc != null &&
                [sunrise, next.sunriseUtc!].any(
                  (instant) =>
                      instant.difference(limb.endsAtUtc!).inSeconds.abs() <=
                      300,
                ),
          ) ||
          [sunrise, arunodaya, next.sunriseUtc!].any(
            (instant) => [tithiStart, tithiEnd, dwadashiEnd].any(
              (boundary) => instant.difference(boundary).inSeconds.abs() <= 300,
            ),
          );
      result.add(
        CalculatedEkadashi(
          date: day.date,
          name: _name(day, ekadashi.paksha == 'Shukla'),
          tradition: tradition,
          rule: rule,
          city: city,
          fastStartsUtc: sunrise,
          paranaDate: next.date,
          paranaStartUtc: parana.$1,
          paranaEndUtc: parana.$2,
          paranaReason: parana.$3,
          hariVasaraEndUtc: hariVasara,
          tithiStartUtc: tithiStart,
          tithiEndUtc: tithiEnd,
          nearBoundary: nearBoundary,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  /// Drik Panchang's Smarta Parana: after sunrise and Hari Vasara (the first
  /// quarter of Dwadashi), preferably in Pratahkala (the first fifth of the
  /// day); if Hari Vasara outlasts Pratahkala, after Madhyahna (the third
  /// fifth) until the end of Aparahna (the fourth fifth). Always before
  /// Dwadashi ends, unless Dwadashi ended before sunrise.
  (DateTime?, DateTime?, String) _smartaParana(
    PanchangDay next,
    DateTime ekadashiEnd,
    DateTime dwadashiEnd,
  ) {
    final sunrise = next.sunriseUtc, sunset = next.sunsetUtc;
    if (sunrise == null || sunset == null || !sunset.isAfter(sunrise)) {
      return (null, null, 'Solar day unavailable');
    }
    final fifth = sunset.difference(sunrise) ~/ 5;
    final hariVasara = ekadashiEnd.add(
      dwadashiEnd.difference(ekadashiEnd) ~/ 4,
    );
    DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
    var begin = later(sunrise, hariVasara);
    late DateTime end;
    late String reason;
    if (begin.isBefore(sunrise.add(fifth))) {
      end = sunrise.add(fifth);
      reason = 'After sunrise and Hari Vasara, within Pratahkala';
    } else {
      begin = later(begin, sunrise.add(fifth * 3));
      end = sunrise.add(fifth * 4);
      reason = 'Hari Vasara outlasts Pratahkala: after Madhyahna';
    }
    if (dwadashiEnd.isAfter(sunrise) && dwadashiEnd.isBefore(end)) {
      end = dwadashiEnd;
      reason = '$reason, before Dwadashi ends';
    }
    if (!end.isAfter(begin)) {
      return (begin, null, '$reason. No bounded window; shown as after-only.');
    }
    return (begin, end, reason);
  }

  (DateTime?, DateTime?, String) _parana(
    PanchangDay fast,
    PanchangDay next,
    EkadashiTradition tradition,
    String rule,
    DateTime hariVasara,
  ) {
    final sunrise = next.sunriseUtc, sunset = next.sunsetUtc;
    if (sunrise == null || sunset == null || !sunset.isAfter(sunrise)) {
      return (null, null, 'Solar day unavailable');
    }
    final third = sunrise.add(sunset.difference(sunrise) ~/ 3);
    final limb = engine.tithiAt(sunrise);
    final tithiEnd = limb.endsAtUtc!;
    DateTime earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
    DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
    var begin = sunrise;
    DateTime? end = earlier(tithiEnd, third);
    var reason =
        'Sunrise to the earlier of tithi end and one third of daylight';
    if (tradition == EkadashiTradition.smarta) {
      begin = later(sunrise, hariVasara);
      end = (limb.index - 1) % 15 + 1 <= 12
          ? earlier(engine.tithiAt(hariVasara).endsAtUtc!, third)
          : third;
      reason =
          'After sunrise and Hari Vasara (first quarter of Dwadashi); before Dwadashi ends and within the morning where possible';
    } else if (rule == 'Trisprisha' || rule == 'Unmilani-Trisprisha') {
      end = third;
      reason = 'Trisprisha: sunrise to one third of daylight';
    } else if (['Jaya', 'Jayanti', 'Papanashini', 'Vijaya'].contains(rule)) {
      final nakEnd = fast.nakshatra.endsAtUtc!;
      if ((limb.index - 1) % 15 + 1 == 12) {
        if (nakEnd.isBefore(tithiEnd)) {
          begin = later(sunrise, nakEnd);
          end = nakEnd.isBefore(third) ? earlier(tithiEnd, third) : tithiEnd;
        }
      } else if (rule == 'Jayanti' || rule == 'Vijaya') {
        end = earlier(nakEnd, third);
      } else {
        begin = later(sunrise, nakEnd);
        end = nakEnd.isBefore(third) ? third : null;
      }
      reason =
          '$rule: nakshatra end, Dwadashi end and morning limit evaluated together';
    } else if (rule != 'Unmilani' &&
        rule != 'Vyanjuli' &&
        (fast.tithi.index - 1) % 15 + 1 != 12) {
      begin = later(sunrise, hariVasara);
      reason =
          'After sunrise and Hari Vasara; before tithi end or one third of daylight';
    }
    if (end != null && !end.isAfter(begin)) end = null;
    return (
      begin,
      end,
      end == null
          ? '$reason. No bounded morning window; shown as after-only.'
          : reason,
    );
  }

  String _name(PanchangDay day, bool bright) {
    if (day.isAdhikaMonth) {
      return bright ? 'Padmini Ekadashi' : 'Parama Ekadashi';
    }
    const months = [
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
    const shukla = [
      'Kamada',
      'Mohini',
      'Nirjala',
      'Devshayani',
      'Shravana Putrada',
      'Parivartini',
      'Papankusha',
      'Devutthana',
      'Mokshada',
      'Pausha Putrada',
      'Jaya',
      'Amalaki',
    ];
    const krishna = [
      'Varuthini',
      'Apara',
      'Yogini',
      'Kamika',
      'Aja',
      'Indira',
      'Rama',
      'Utpanna',
      'Saphala',
      'Shattila',
      'Vijaya',
      'Papamochani',
    ];
    final index = months.indexOf(day.amantaMonth);
    return index < 0
        ? 'Ekadashi'
        : '${(bright ? shukla : krishna)[index]} Ekadashi';
  }
}
