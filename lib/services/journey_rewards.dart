import 'dart:math' as math;
import 'package:timezone/timezone.dart' as tz;
import '../models/vrat_tracker_models.dart';
import '../widgets/app_icons.dart';
import 'achievement_evaluator.dart';
import 'ekadashi_service.dart';
import 'vrat_recording.dart';

/// Mirrors EkadashiCore JourneyRewards. History is authoritative, never a wallet.
class JourneySegment {
  const JourneySegment(this.id, this.date, this.status, this.isFuture);
  final String id;
  final DateTime date;
  final ObservanceStatus status;
  final bool isFuture;
  int get points => isFuture
      ? 0
      : status == ObservanceStatus.observed
      ? 100
      : status == ObservanceStatus.partial
      ? 50
      : 0;
}

class JourneyQuarter {
  const JourneyQuarter(this.id, this.total, this.observed, this.completed);
  final int id, total, observed;
  final bool completed;
  int get points => completed ? 150 : 0;
}

class JourneyYear {
  const JourneyYear(
    this.year,
    this.segments,
    this.quarters,
    this.scheduleComplete,
  );
  final int year;
  final List<JourneySegment> segments;
  final List<JourneyQuarter> quarters;
  final bool scheduleComplete;
  int get basePoints => segments.fold(0, (s, e) => s + e.points);
  int get observed => segments
      .where((e) => !e.isFuture && e.status == ObservanceStatus.observed)
      .length;
  int get partial => segments
      .where((e) => !e.isFuture && e.status == ObservanceStatus.partial)
      .length;
  int get annualBonus =>
      scheduleComplete &&
          segments.isNotEmpty &&
          quarters.every((q) => q.completed)
      ? 1000
      : 0;
  int get points =>
      basePoints + quarters.fold<int>(0, (s, q) => s + q.points) + annualBonus;
  int get maximumPoints =>
      segments.length * 100 +
      (scheduleComplete && segments.isNotEmpty ? 1600 : 0);
}

class JourneySummary {
  const JourneySummary(
    this.years,
    this.observedCount,
    this.partialCount,
    this.currentStreak,
    this.longestStreak,
    this.hasReturned, {
    this.fullCurrentStreak = 0,
    this.fullLongestStreak = 0,
    this.asOf,
  });
  final Map<int, JourneyYear> years;
  final DateTime? asOf;
  final int observedCount, partialCount, currentStreak, longestStreak;
  final bool hasReturned;
  final int fullCurrentStreak, fullLongestStreak;
  int get lifetimePoints =>
      observedCount * 100 +
      partialCount * 50 +
      years.values.fold<int>(0, (s, y) => s + y.points - y.basePoints);
  List<JourneySegment> get segments =>
      (years.keys.toList()..sort()).expand((y) => years[y]!.segments).toList();
  List<JourneySegment> get eligibleSegments =>
      segments.where((e) => !e.isFuture).toList();
  List<int> get visibleYears =>
      years.keys
          .where((y) => y >= 2026 && y <= (asOf ?? DateTime.now()).year)
          .toList()
        ..sort((a, b) => b.compareTo(a));
  JourneySummary scoped({int? toYear}) {
    final selected = Map<int, JourneyYear>.fromEntries(
      years.entries.where(
        (e) => toYear != null
            ? e.key == toYear
            : e.key >= 2026 && e.key <= (asOf ?? DateTime.now()).year,
      ),
    );
    final ordered = (selected.keys.toList()..sort())
        .expand((y) => selected[y]!.segments)
        .toList();
    final eligible = ordered.where((e) => !e.isFuture);
    final observed = eligible
        .where((e) => e.status == ObservanceStatus.observed)
        .length;
    final partial = eligible
        .where((e) => e.status == ObservanceStatus.partial)
        .length;
    final streak = JourneyRewards._streaks(ordered);
    return JourneySummary(
      selected,
      observed,
      partial,
      streak.current,
      streak.longest,
      streak.returned,
      fullCurrentStreak: streak.fullCurrent,
      fullLongestStreak: streak.fullLongest,
      asOf: asOf,
    );
  }

  JourneyBadgeDefinition? nextMilestone(Map<String, UserAchievement> earned) {
    final periodEarned = <String, UserAchievement>{};
    for (final badge in JourneyBadgeCatalog.all(years.keys.toList())) {
      if (badge.progress(this) >= badge.target &&
          earned[badge.id]?.isUnlocked == true) {
        periodEarned[badge.id] = earned[badge.id]!;
      }
    }
    return JourneyBadgeCatalog.nextMilestone(this, periodEarned);
  }

  JourneyYear year(int y) =>
      years[y] ??
      JourneyYear(y, [], [
        for (var i = 1; i <= 4; i++) JourneyQuarter(i, 0, 0, false),
      ], false);
}

abstract final class JourneyRewards {
  static JourneySummary calculate({
    required List<EkadashiDate> occurrences,
    required List<VratHistory> history,
    required Set<int> completeYears,
    DateTime? now,
    String timezone = 'Asia/Kolkata',
  }) {
    final instant = now ?? DateTime.now();
    final events = <String, EkadashiDate>{};
    for (final e in occurrences) {
      events.putIfAbsent(e.occurrenceUid, () => e);
    }
    final ordered = events.values.toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c == 0 ? a.occurrenceUid.compareTo(b.occurrenceUid) : c;
      });
    final records = <String, VratHistory>{};
    final rows = history.toList()
      ..sort((a, b) {
        final c = a.updatedAtUTC.compareTo(b.updatedAtUTC);
        return c == 0 ? a.id.compareTo(b.id) : c;
      });
    for (final row in rows) {
      final d = DateTime.tryParse(row.ekadashiDate);
      if (d == null) continue;
      records[row.occurrenceUid ??
              'ekadashi:${d.year}:${row.ekadashiOccurrenceId.toString().padLeft(2, '0')}'] =
          row;
    }
    final aliases = {
      'IST': 'Asia/Kolkata',
      'PST': 'America/Los_Angeles',
      'EST': 'America/New_York',
      'CST': 'America/Chicago',
      'MST': 'America/Denver',
    };
    DateTime local;
    try {
      local = tz.TZDateTime.from(
        instant,
        tz.getLocation(aliases[timezone] ?? timezone),
      );
    } catch (_) {
      local = instant.toUtc().add(const Duration(hours: 5, minutes: 30));
    }
    final today = DateTime(local.year, local.month, local.day);
    var observed = 0, partial = 0;
    for (final entry in records.entries) {
      final d = DateTime.tryParse(entry.value.ekadashiDate);
      if (d == null || d.isAfter(today)) continue;
      final e = events[entry.key];
      if (e != null &&
          !VratRecording.isOpen(e, now: instant, timezone: timezone)) {
        continue;
      }
      if (entry.value.status == ObservanceStatus.observed) observed++;
      if (entry.value.status == ObservanceStatus.partial) partial++;
    }
    final segments = [
      for (final e in ordered)
        JourneySegment(
          e.occurrenceUid,
          e.date,
          records[e.occurrenceUid]?.status ?? ObservanceStatus.unrecorded,
          !VratRecording.isOpen(e, now: instant, timezone: timezone),
        ),
    ];
    final years = <int, JourneyYear>{};
    for (final y in segments.map((e) => e.date.year).toSet()) {
      final list = segments.where((e) => e.date.year == y).toList();
      final qs = [
        for (var q = 0; q < 4; q++)
          list.where((e) => (e.date.month - 1) ~/ 3 == q).toList(),
      ];
      final complete =
          completeYears.contains(y) && qs.every((q) => q.isNotEmpty);
      years[y] = JourneyYear(y, list, [
        for (var q = 0; q < 4; q++)
          JourneyQuarter(
            q + 1,
            qs[q].length,
            qs[q]
                .where(
                  (e) => !e.isFuture && e.status == ObservanceStatus.observed,
                )
                .length,
            complete &&
                qs[q].every(
                  (e) => !e.isFuture && e.status == ObservanceStatus.observed,
                ),
          ),
      ], complete);
    }
    final streak = _streaks(segments);
    return JourneySummary(
      years,
      observed,
      partial,
      streak.current,
      streak.longest,
      streak.returned,
      fullCurrentStreak: streak.fullCurrent,
      fullLongestStreak: streak.fullLongest,
      asOf: today,
    );
  }

  static ({
    int current,
    int longest,
    int fullCurrent,
    int fullLongest,
    bool returned,
  })
  _streaks(List<JourneySegment> segments) {
    var run = 0, longest = 0, returned = false;
    var fullRun = 0, fullLongest = 0;
    final eligible = segments.where((e) => !e.isFuture).toList();
    final lastRecorded = eligible.lastIndexWhere(
      (e) => e.status != ObservanceStatus.unrecorded,
    );
    JourneySegment? previous;
    for (final e in eligible.take(lastRecorded + 1)) {
      if (e.status == ObservanceStatus.observed) {
        fullRun++;
        fullLongest = math.max(fullLongest, fullRun);
        if (previous?.status == ObservanceStatus.missed) returned = true;
      } else {
        fullRun = 0;
      }
      if (e.status == ObservanceStatus.observed ||
          e.status == ObservanceStatus.partial) {
        run++;
        longest = math.max(longest, run);
      } else {
        run = 0;
      }
      previous = e;
    }
    return (
      current: run,
      longest: longest,
      fullCurrent: fullRun,
      fullLongest: fullLongest,
      returned: returned,
    );
  }
}

enum JourneyRule {
  observed,
  streak,
  partial,
  returned,
  quarter,
  annual,
  legacyAnnual,
}

enum JourneyArt {
  lamp,
  leaves,
  lotus,
  lights,
  flame,
  arcs,
  thread,
  wreath,
  sunrise,
  petals,
  quarter,
  annual,
}

class JourneyBadgeDefinition {
  const JourneyBadgeDefinition(
    this.achievement,
    this.rule,
    this.art, {
    this.year,
    this.quarter,
  });
  final Achievement achievement;
  final JourneyRule rule;
  final JourneyArt art;
  final int? year, quarter;
  bool isVisibleInYear(int? selectedYear) =>
      selectedYear == null || year == null || year == selectedYear;
  String get id => achievement.id;
  int get target => achievement.targetValue;
  int progress(JourneySummary s) {
    final value = switch (rule) {
      JourneyRule.observed => s.observedCount,
      JourneyRule.streak => s.fullLongestStreak,
      JourneyRule.partial => s.partialCount,
      JourneyRule.returned => s.hasReturned ? 1 : 0,
      JourneyRule.quarter =>
        s.year(year!).quarters[quarter! - 1].completed ? 1 : 0,
      JourneyRule.annual => s.year(year!).annualBonus > 0 ? 1 : 0,
      JourneyRule.legacyAnnual =>
        s.years.values.any((y) => y.annualBonus > 0) ? target : 0,
    };
    return value.clamp(0, target);
  }

  int goalProgress(JourneySummary s) => rule == JourneyRule.streak
      ? math.min(target, s.fullCurrentStreak)
      : progress(s);
}

abstract final class JourneyBadgeCatalog {
  static List<JourneyBadgeDefinition> all(List<int> years) {
    final rows = <(String, String, JourneyRule, JourneyArt, int)>[
      ('first_vrat', 'first', JourneyRule.observed, JourneyArt.lamp, 1),
      ('vrat_5', 'root', JourneyRule.observed, JourneyArt.leaves, 5),
      ('vrat_10', 'bloom', JourneyRule.observed, JourneyArt.lotus, 10),
      ('vrat_12', 'lights', JourneyRule.observed, JourneyArt.lights, 12),
      (
        'consistent_observance',
        'flame',
        JourneyRule.streak,
        JourneyArt.flame,
        3,
      ),
      ('streak_6', 'rhythm', JourneyRule.streak, JourneyArt.arcs, 6),
      ('streak_12', 'thread', JourneyRule.streak, JourneyArt.thread, 12),
      ('streak_24', 'wreath', JourneyRule.streak, JourneyArt.wreath, 24),
      ('welcome_back', 'return', JourneyRule.returned, JourneyArt.sunrise, 1),
      ('every_effort', 'effort', JourneyRule.partial, JourneyArt.petals, 3),
    ];
    final out = <JourneyBadgeDefinition>[];
    JourneyBadgeDefinition badge(
      String id,
      String key,
      JourneyRule rule,
      JourneyArt art,
      int target, {
      int? year,
      int? quarter,
    }) => JourneyBadgeDefinition(
      Achievement(
        id: id,
        key: id,
        titleKey: 'ios_journey_badge_$key',
        descriptionKey: 'ios_journey_badge_${key}_desc',
        conditionType: 'count',
        targetValue: target,
        icon: AppIcons.achievementFirst,
        sortOrder: out.length + 1,
      ),
      rule,
      art,
      year: year,
      quarter: quarter,
    );
    for (final r in rows) {
      out.add(badge(r.$1, r.$2, r.$3, r.$4, r.$5));
    }
    out.add(
      JourneyBadgeDefinition(
        AchievementEvaluator.allAchievements.last,
        JourneyRule.legacyAnnual,
        JourneyArt.annual,
      ),
    );
    for (final y in (years.toSet().toList()..sort()).where(
      (y) => y == 2026 || y == 2027,
    )) {
      for (var q = 1; q <= 4; q++) {
        out.add(
          badge(
            'journey_${y}_q$q',
            'q$q',
            JourneyRule.quarter,
            JourneyArt.quarter,
            1,
            year: y,
            quarter: q,
          ),
        );
      }
      out.add(
        badge(
          'journey_${y}_full',
          'annual',
          JourneyRule.annual,
          JourneyArt.annual,
          1,
          year: y,
        ),
      );
    }
    return out;
  }

  static JourneyBadgeDefinition? definition(String id) =>
      all([2026, 2027]).where((b) => b.id == id).firstOrNull;
  static JourneyBadgeDefinition? nextMilestone(
    JourneySummary s,
    Map<String, UserAchievement> earned,
  ) {
    final list = all([])
        .where(
          (b) =>
              earned[b.id]?.isUnlocked != true &&
              (b.rule == JourneyRule.observed || b.rule == JourneyRule.streak),
        )
        .toList();
    list.sort((a, b) {
      final d = (a.target - a.goalProgress(s)).compareTo(
        b.target - b.goalProgress(s),
      );
      return d == 0
          ? a.achievement.sortOrder.compareTo(b.achievement.sortOrder)
          : d;
    });
    return list.firstOrNull;
  }
}

abstract final class JourneyBadgeEvaluator {
  static ({
    Map<String, UserAchievement> updated,
    List<Achievement> newlyUnlocked,
  })
  evaluate({
    required JourneySummary summary,
    required Map<String, UserAchievement> current,
    int? newUnlockLimit,
    required DateTime now,
  }) {
    final updated = {...current}, newly = <Achievement>[];
    var remaining = math.max(0, newUnlockLimit ?? 0x7fffffff);
    final stamp = now.toUtc().toIso8601String();
    for (final b in JourneyBadgeCatalog.all(summary.years.keys.toList())) {
      final previous = current[b.id],
          was = previous?.isUnlocked ?? false,
          progress = b.progress(summary);
      final unlocked = progress == b.target && (was || remaining > 0);
      if (unlocked && !was) {
        remaining--;
        newly.add(b.achievement);
      }
      updated[b.id] = UserAchievement(
        id: previous?.id ?? 'ua_${b.id}',
        achievementId: b.id,
        progressValue: progress,
        isUnlocked: unlocked,
        unlockedAtUTC: unlocked
            ? (was ? previous?.unlockedAtUTC : stamp)
            : null,
        lastEvaluatedAtUTC: stamp,
      );
    }
    return (updated: updated, newlyUnlocked: newly);
  }
}
