import 'panchang_city.dart';

const istOffset = Duration(hours: 5, minutes: 30);

/// A UTC instant expressed as a wall clock in IST when inspecting its fields.
/// It remains UTC so its fields are deterministic on every device timezone.
DateTime istWallClock(DateTime instantUtc) => instantUtc.toUtc().add(istOffset);

String formatIstTime(DateTime? instantUtc) {
  if (instantUtc == null) return '—';
  final local = istWallClock(instantUtc);
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

String formatIstDateTime(DateTime? instantUtc) {
  if (instantUtc == null) return '—';
  final local = istWallClock(instantUtc);
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[local.weekday - 1]}, ${months[local.month - 1]} '
      '${local.day}, ${local.year} · ${formatIstTime(instantUtc)} IST';
}

class PanchangLimb {
  const PanchangLimb({
    required this.index,
    required this.name,
    required this.endsAtUtc,
    this.paksha,
  });

  final int index;
  final String name;
  final DateTime? endsAtUtc;
  final String? paksha;
}

class PanchangObservance {
  const PanchangObservance({
    required this.id,
    required this.name,
    required this.ruleSource,
    this.description = '',
    this.isMajor = false,
  });

  final String id;
  final String name;
  final String ruleSource;
  final String description;
  final bool isMajor;
}

class PanchangPeriod {
  const PanchangPeriod({
    required this.name,
    required this.startUtc,
    required this.endUtc,
  });

  final String name;
  final DateTime startUtc;
  final DateTime endUtc;
}

class PanchangDay {
  const PanchangDay({
    this.sunRashiEndsAtUtc,
    this.moonRashiEndsAtUtc,
    this.padaEndsAtUtc,
    this.lagna = const [],
    this.anandadiYoga = '',
    this.shakaYear = 0,
    this.vikramaYear = 0,
    this.hora = const [],
    this.additionalPeriods = const [],
    this.specialYogas = const [],
    this.nakshatraPada = 1,
    this.ayanamsa = 0,
    this.isAdhikaMonth = false,
    this.ritu = '',
    this.ayana = '',
    this.moonsetUtc,
    this.nextSunriseUtc,
    this.sunRashi = '',
    this.moonRashi = '',
    this.abhijit,
    this.brahmaMuhurta,
    this.choghadiya = const [],
    this.limbTimeline = const {},
    required this.date,
    required this.city,
    required this.sunriseUtc,
    required this.sunsetUtc,
    required this.moonriseUtc,
    required this.tithi,
    required this.nakshatra,
    required this.yoga,
    required this.karana,
    required this.vara,
    required this.amantaMonth,
    required this.purnimantaMonth,
    required this.rahukala,
    required this.yamaganda,
    required this.gulika,
    required this.observances,
  });

  final DateTime? sunRashiEndsAtUtc;
  final DateTime? moonRashiEndsAtUtc;
  final DateTime? padaEndsAtUtc;
  final List<PanchangPeriod> lagna;
  final String anandadiYoga;
  final int shakaYear;
  final int vikramaYear;
  final List<PanchangPeriod> hora;
  final List<PanchangPeriod> additionalPeriods;
  final List<String> specialYogas;
  final int nakshatraPada;
  final double ayanamsa;
  final bool isAdhikaMonth;
  final String ritu;
  final String ayana;
  final DateTime? moonsetUtc;
  final DateTime? nextSunriseUtc;
  final String sunRashi;
  final String moonRashi;
  final PanchangPeriod? abhijit;
  final PanchangPeriod? brahmaMuhurta;
  final List<PanchangPeriod> choghadiya;
  final Map<String, List<PanchangLimb>> limbTimeline;

  /// Calendar date in the selected location. The UTC constructor prevents host-local shifts.
  final DateTime date;
  final PanchangCity city;
  final DateTime? sunriseUtc;
  final DateTime? sunsetUtc;
  final DateTime? moonriseUtc;
  final PanchangLimb tithi;
  final PanchangLimb nakshatra;
  final PanchangLimb yoga;
  final PanchangLimb karana;
  final String vara;
  final String amantaMonth;
  final String purnimantaMonth;
  final PanchangPeriod? rahukala;
  final PanchangPeriod? yamaganda;
  final PanchangPeriod? gulika;
  final List<PanchangObservance> observances;

  DateTime? get sunriseIst =>
      sunriseUtc == null ? null : istWallClock(sunriseUtc!);
  DateTime? get sunsetIst =>
      sunsetUtc == null ? null : istWallClock(sunsetUtc!);
  DateTime? get moonriseIst =>
      moonriseUtc == null ? null : istWallClock(moonriseUtc!);
}

/// Includes a date marker for events outside the selected civil day and an
/// abbreviation/offset so repeated DST wall times remain distinguishable.
String formatPanchangTime(DateTime? instant, PanchangCity city, DateTime date) {
  if (instant == null) return '—';
  final local = city.wallClock(instant);
  final day = DateTime.utc(local.year, local.month, local.day);
  final selected = DateTime.utc(date.year, date.month, date.day);
  final delta = day.difference(selected).inDays;
  final suffix = delta == 0 ? '' : ' (${delta > 0 ? '+' : ''}$delta day)';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final offset = local.timeZoneOffset.inMinutes;
  final offsetText =
      '${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}';
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'} ${local.timeZoneName} (UTC$offsetText)$suffix';
}
