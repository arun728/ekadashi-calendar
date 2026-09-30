import 'package:flutter/material.dart';
import '../models/vrat_tracker_models.dart';
import 'ekadashi_service.dart';
import 'vrat_statistics_service.dart';

/// Service responsible for evaluating and unlocking devotional achievements.
/// The Achievement System is part of the same module and directly consumes
/// Vrat Tracker history and statistics.
class AchievementEvaluator {
  /// Standard list of milestones defined for Ekadashi observance
  static const List<Achievement> allAchievements = [
    Achievement(
      id: 'first_vrat',
      key: 'first_vrat',
      titleKey: 'achievement_first_vrat_title',
      descriptionKey: 'achievement_first_vrat_desc',
      conditionType: 'count',
      targetValue: 1,
      icon: Icons.spa,
      sortOrder: 1,
    ),
    Achievement(
      id: 'vrat_5',
      key: 'vrat_5',
      titleKey: 'achievement_5_vrat_title',
      descriptionKey: 'achievement_5_vrat_desc',
      conditionType: 'count',
      targetValue: 5,
      icon: Icons.star_border,
      sortOrder: 2,
    ),
    Achievement(
      id: 'vrat_10',
      key: 'vrat_10',
      titleKey: 'achievement_10_vrat_title',
      descriptionKey: 'achievement_10_vrat_desc',
      conditionType: 'count',
      targetValue: 10,
      icon: Icons.military_tech_outlined,
      sortOrder: 3,
    ),
    Achievement(
      id: 'vrat_12',
      key: 'vrat_12',
      titleKey: 'achievement_12_vrat_title',
      descriptionKey: 'achievement_12_vrat_desc',
      conditionType: 'count',
      targetValue: 12,
      icon: Icons.workspace_premium_outlined,
      sortOrder: 4,
    ),
    Achievement(
      id: 'consistent_observance',
      key: 'consistent_observance',
      titleKey: 'achievement_consistent_title',
      descriptionKey: 'achievement_consistent_desc',
      conditionType: 'streak',
      targetValue: 3,
      icon: Icons.bolt,
      sortOrder: 5,
    ),
    Achievement(
      id: 'full_year_observance',
      key: 'full_year_observance',
      titleKey: 'achievement_full_year_title',
      descriptionKey: 'achievement_full_year_desc',
      conditionType: 'annual_full',
      targetValue: 100, // 100% of year occurrences
      icon: Icons.brightness_high,
      sortOrder: 6,
    ),
  ];

  /// Evaluates all achievements given the current tracker records and occurrences.
  ///
  /// Returns a record with:
  /// - updated map of UserAchievement
  /// - list of newly unlocked achievements (for one-time notification)
  static ({
    Map<String, UserAchievement> updatedAchievements,
    List<Achievement> newlyUnlocked,
  }) evaluate({
    required List<VratHistory> history,
    required List<EkadashiDate> occurrences,
    required Map<String, UserAchievement> currentAchievements,
  }) {
    final Map<int, VratHistory> historyByOccId = {
      for (final h in history) h.ekadashiOccurrenceId: h,
    };

    // Calculate metrics
    final totalObservedCount = history.where((h) => h.status == ObservanceStatus.observed).length;
    final longestStreak = VratStatisticsService.calculateLongestStreak(
      occurrences: occurrences,
      historyByOccurrenceId: historyByOccId,
    );

    // Check full-year observance for any calendar year present in history
    final availableYears = VratStatisticsService.getAvailableYears(
      occurrences: occurrences,
      history: history,
    );

    bool hasFullYear = false;
    for (final year in availableYears) {
      final yearStats = VratStatisticsService.calculateAnnualStats(
        year: year,
        occurrences: occurrences,
        historyByOccurrenceId: historyByOccId,
      );
      if (yearStats.totalOccurrences > 0 &&
          yearStats.observedCount >= yearStats.totalOccurrences) {
        hasFullYear = true;
        break;
      }
    }

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final updated = Map<String, UserAchievement>.from(currentAchievements);
    final newlyUnlocked = <Achievement>[];

    for (final achievement in allAchievements) {
      final existing = updated[achievement.id];
      final wasUnlocked = existing?.isUnlocked ?? false;

      int progress = 0;
      bool meetsCondition = false;

      switch (achievement.conditionType) {
        case 'count':
          progress = totalObservedCount.clamp(0, achievement.targetValue);
          meetsCondition = totalObservedCount >= achievement.targetValue;
          break;
        case 'streak':
          progress = longestStreak.clamp(0, achievement.targetValue);
          meetsCondition = longestStreak >= achievement.targetValue;
          break;
        case 'annual_full':
          progress = hasFullYear ? 100 : 0;
          meetsCondition = hasFullYear;
          break;
      }

      final isNowUnlocked = wasUnlocked || meetsCondition;
      final String? unlockedTime = wasUnlocked
          ? existing?.unlockedAtUTC
          : (isNowUnlocked ? nowUtc : null);

      if (!wasUnlocked && isNowUnlocked) {
        newlyUnlocked.add(achievement);
      }

      updated[achievement.id] = UserAchievement(
        id: existing?.id ?? 'ua_${achievement.id}',
        achievementId: achievement.id,
        progressValue: progress,
        isUnlocked: isNowUnlocked,
        unlockedAtUTC: unlockedTime,
        lastEvaluatedAtUTC: nowUtc,
      );
    }

    return (
      updatedAchievements: updated,
      newlyUnlocked: newlyUnlocked,
    );
  }

  /// Find the next unearned milestone to display on the dashboard
  static ({Achievement achievement, int currentProgress, int target})? getNextMilestone({
    required Map<String, UserAchievement> userAchievements,
    required int totalObserved,
    required int longestStreak,
  }) {
    for (final ach in allAchievements) {
      final userAch = userAchievements[ach.id];
      final isUnlocked = userAch?.isUnlocked ?? false;
      if (!isUnlocked) {
        int progress = 0;
        switch (ach.conditionType) {
          case 'count':
            progress = totalObserved;
            break;
          case 'streak':
            progress = longestStreak;
            break;
          case 'annual_full':
            progress = 0;
            break;
        }
        return (
          achievement: ach,
          currentProgress: progress.clamp(0, ach.targetValue),
          target: ach.targetValue,
        );
      }
    }
    return null;
  }
}
