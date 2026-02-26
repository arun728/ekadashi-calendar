/// Ekadashi Date Utility Functions
///
/// Helper functions for calculating and formatting Ekadashi-related dates.
/// Ekadashi occurs on the 11th day of each lunar fortnight (waxing and waning).

library ekadashi_date_utils;

import 'package:intl/intl.dart';

/// Returns true if [date] falls on an Ekadashi day.
bool isEkadashi(DateTime date) {
  // Ekadashi is the 11th tithi of each paksha (fortnight)
  // This is a simplified check; production should use ephemeris data
  final tithi = getTithi(date);
  return tithi == 11;
}

/// Returns the tithi (lunar day, 1–30) for a given [date].
/// Returns -1 if the tithi cannot be determined.
int getTithi(DateTime date) {
  // Placeholder: integrate with ephemeris library for accurate calculation
  // Tithi index within the synodic month (29.53 days)
  const synodicMonth = 29.53058867;
  const referenceNewMoon = 2451550.1; // Julian date of a known new moon

  final jd = _toJulianDate(date);
  final daysSinceNew = (jd - referenceNewMoon) % synodicMonth;
  final tithi = (daysSinceNew / synodicMonth * 30).floor() + 1;
  return tithi.clamp(1, 30);
}

/// Formats an Ekadashi date for display.
/// Returns a string like "Ekadashi — 12 Jan 2026 (Shukla Paksha)".
String formatEkadashiDate(DateTime date) {
  final paksha = _getPaksha(date);
  final formatted = DateFormat('d MMM yyyy').format(date);
  return 'Ekadashi — $formatted ($paksha)';
}

/// Returns the next Ekadashi date after [from].
DateTime nextEkadashi(DateTime from) {
  var candidate = from.add(const Duration(days: 1));
  for (int i = 0; i < 30; i++) {
    if (isEkadashi(candidate)) return candidate;
    candidate = candidate.add(const Duration(days: 1));
  }
  throw StateError('Could not find next Ekadashi within 30 days');
}

/// Returns all Ekadashi dates in a given [month] and [year].
List<DateTime> ekadashiDatesInMonth(int year, int month) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  return List.generate(daysInMonth, (i) => DateTime(year, month, i + 1))
      .where(isEkadashi)
      .toList();
}

// ── Private helpers ───────────────────────────────────────────────────────────

String _getPaksha(DateTime date) {
  final tithi = getTithi(date);
  return tithi <= 15 ? 'Shukla Paksha' : 'Krishna Paksha';
}

double _toJulianDate(DateTime date) {
  final y = date.year;
  final m = date.month;
  final d = date.day + date.hour / 24.0;
  final a = ((14 - m) / 12).floor();
  final y2 = y + 4800 - a;
  final m2 = m + 12 * a - 3;
  return d +
      ((153 * m2 + 2) / 5).floor() +
      365 * y2 +
      (y2 / 4).floor() -
      (y2 / 100).floor() +
      (y2 / 400).floor() -
      32045;
}
