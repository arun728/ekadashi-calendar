import '../models/vrat_tracker_models.dart';
import 'ekadashi_service.dart';

/// Centralized service for calculating Vrat Tracker statistics and streaks.
/// This is the single source of truth for streak and observance numbers.
class VratStatisticsService {
  /// Calculate the current consecutive-observance streak.
  ///
  /// Rule:
  /// - Sequences Ekadashi occurrences chronologically up to [asOfDate].
  /// - Walks backwards from the most recently completed/recorded Ekadashi.
  /// - OBSERVED increments streak.
  /// - MISSED breaks streak.
  /// - PARTIAL does not count towards the full-observance streak (breaks current streak).
  /// - UNRECORDED breaks streak if the event has already passed.
  static int calculateCurrentStreak({
    required List<EkadashiDate> occurrences,
    required Map<int, VratHistory> historyByOccurrenceId,
    DateTime? asOfDate,
    DateTime? trackingEnabledAt,
  }) {
    if (occurrences.isEmpty || historyByOccurrenceId.isEmpty) return 0;

    final now = asOfDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter to occurrences that have happened (on or before today)
    final pastOccurrences = occurrences
        .where((e) {
          final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
          return !eventDate.isAfter(today);
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (pastOccurrences.isEmpty) return 0;

    int streak = 0;
    // Iterate backwards from the most recent past occurrence
    for (int i = pastOccurrences.length - 1; i >= 0; i--) {
      final occurrence = pastOccurrences[i];
      final record = historyByOccurrenceId[occurrence.id];

      // If user enabled tracking later and past occurrences are unrecorded before trackingEnabledAt,
      // we check if they recorded anything.
      if (record != null) {
        if (record.status == ObservanceStatus.observed) {
          streak++;
        } else {
          // Missed or Partial breaks the current streak
          break;
        }
      } else {
        // Unrecorded event
        // If we haven't started counting a streak yet (e.g. today's Ekadashi is ongoing and unrecorded),
        // we can allow checking the previous completed one.
        if (streak == 0 && i == pastOccurrences.length - 1) {
          final eventDate = DateTime(occurrence.date.year, occurrence.date.month, occurrence.date.day);
          if (eventDate.isAtSameMomentAs(today)) {
            // Today's Ekadashi is in progress and not yet recorded; look back to previous
            continue;
          }
        }
        // An unrecorded past Ekadashi breaks the consecutive streak
        break;
      }
    }

    return streak;
  }

  /// Calculate the longest consecutive-observance streak ever achieved.
  ///
  /// Evaluates the entire chronological sequence of Ekadashis to find
  /// the maximum run of consecutive OBSERVED entries.
  static int calculateLongestStreak({
    required List<EkadashiDate> occurrences,
    required Map<int, VratHistory> historyByOccurrenceId,
  }) {
    if (occurrences.isEmpty || historyByOccurrenceId.isEmpty) return 0;

    final sorted = List<EkadashiDate>.from(occurrences)
      ..sort((a, b) => a.date.compareTo(b.date));

    int longest = 0;
    int currentRun = 0;

    for (final occurrence in sorted) {
      final record = historyByOccurrenceId[occurrence.id];
      if (record != null && record.status == ObservanceStatus.observed) {
        currentRun++;
        if (currentRun > longest) {
          longest = currentRun;
        }
      } else {
        currentRun = 0;
      }
    }

    return longest;
  }

  /// Calculate annual completion statistics for a given [year].
  ///
  /// The denominator comes dynamically from [occurrences] for that year (provided by Module 10).
  /// Formula: (observedCount / totalOccurrences) * 100.
  static VratYearStats calculateAnnualStats({
    required int year,
    required List<EkadashiDate> occurrences,
    required Map<int, VratHistory> historyByOccurrenceId,
  }) {
    // Filter occurrences for the requested year
    final yearOccurrences = occurrences.where((e) => e.date.year == year).toList();
    final totalOccurrences = yearOccurrences.length;

    int observed = 0;
    int partial = 0;
    int missed = 0;
    int unrecorded = 0;

    for (final occ in yearOccurrences) {
      final record = historyByOccurrenceId[occ.id];
      if (record == null || record.status == ObservanceStatus.unrecorded) {
        unrecorded++;
      } else if (record.status == ObservanceStatus.observed) {
        observed++;
      } else if (record.status == ObservanceStatus.partial) {
        partial++;
      } else if (record.status == ObservanceStatus.missed) {
        missed++;
      }
    }

    final double completionPercentage = totalOccurrences > 0
        ? (observed / totalOccurrences) * 100.0
        : 0.0;

    return VratYearStats(
      year: year,
      totalOccurrences: totalOccurrences,
      observedCount: observed,
      partialCount: partial,
      missedCount: missed,
      unrecordedCount: unrecorded,
      completionPercentage: completionPercentage,
    );
  }

  /// Get all available years from occurrences and recorded history
  static List<int> getAvailableYears({
    required List<EkadashiDate> occurrences,
    required List<VratHistory> history,
  }) {
    final years = <int>{};
    for (final occ in occurrences) {
      years.add(occ.date.year);
    }
    for (final h in history) {
      final parsed = DateTime.tryParse(h.ekadashiDate);
      if (parsed != null) {
        years.add(parsed.year);
      }
    }
    if (years.isEmpty) {
      years.add(DateTime.now().year);
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }
}
