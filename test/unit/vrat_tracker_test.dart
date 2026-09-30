import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/services/vrat_statistics_service.dart';
import 'package:ekadashi_calendar/services/achievement_evaluator.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to generate mock Ekadashi occurrences for testing
  List<EkadashiDate> generateMockEkadashis({int year = 2026, int count = 25}) {
    return List.generate(count, (i) {
      final month = ((i * 14) ~/ 30) + 1;
      final day = ((i * 14) % 28) + 1;
      return EkadashiDate(
        id: i + 1,
        name: 'Ekadashi #${i + 1}',
        date: DateTime(year, month.clamp(1, 12), day.clamp(1, 28)),
        fastStartTime: '06:00 AM',
        fastBreakTime: '06:30 AM - 10:00 AM',
        description: 'Test description for Ekadashi ${i + 1}',
        fastingStartIso: '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}T06:00:00+05:30',
        paranaStartIso: '$year-${month.toString().padLeft(2, '0')}-${(day + 1).toString().padLeft(2, '0')}T06:30:00+05:30',
        paranaEndIso: '$year-${month.toString().padLeft(2, '0')}-${(day + 1).toString().padLeft(2, '0')}T10:00:00+05:30',
      );
    });
  }

  group('Module 04: Vrat Tracker Opt-in & Data Preservation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Tracker is disabled by default (Opt-In Requirement)', () async {
      final service = VratTrackerService();
      await service.init();

      expect(service.trackerEnabled, isFalse);
      expect(service.trackingEnabledAt, isNull);
      expect(service.getAllRecords(), isEmpty);
    });

    test('Enabling tracker sets trackingEnabledAt timestamp', () async {
      final service = VratTrackerService();
      await service.init();

      await service.enableTracker();

      expect(service.trackerEnabled, isTrue);
      expect(service.trackingEnabledAt, isNotNull);
      // Historical events remain unrecorded by default
      expect(service.getAllRecords(), isEmpty);
    });

    test('Disabling tracker keeps existing history and earned achievements intact', () async {
      final service = VratTrackerService();
      final mockOccurrences = generateMockEkadashis();
      await service.init(occurrences: mockOccurrences);
      await service.enableTracker(occurrences: mockOccurrences);

      // Record an observance
      await service.recordVrat(
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2026-01-14',
        ekadashiName: 'Shattila Ekadashi',
        status: ObservanceStatus.observed,
        fastingMethod: FastingMethod.fullFast,
        occurrences: mockOccurrences,
      );

      expect(service.getAllRecords().length, 1);
      final firstVratAch = service.userAchievements['first_vrat'];
      expect(firstVratAch?.isUnlocked, isTrue);

      // Disable tracker
      await service.disableTracker();
      expect(service.trackerEnabled, isFalse);

      // Verify records and achievements are NOT deleted
      expect(service.getAllRecords().length, 1);
      expect(service.userAchievements['first_vrat']?.isUnlocked, isTrue);
    });
  });

  group('Module 04: Observance CRUD & Duplicate Record Protection', () {
    late VratTrackerService service;
    late List<EkadashiDate> mockOccurrences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = VratTrackerService();
      mockOccurrences = generateMockEkadashis();
      await service.init(occurrences: mockOccurrences);
      await service.enableTracker(occurrences: mockOccurrences);
    });

    test('Records an observance with fasting method and optional note', () async {
      await service.recordVrat(
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2026-01-14',
        ekadashiName: 'Shattila Ekadashi',
        status: ObservanceStatus.observed,
        fastingMethod: FastingMethod.waterOnly,
        note: 'Felt very peaceful',
        occurrences: mockOccurrences,
      );

      final record = service.getRecord(1);
      expect(record, isNotNull);
      expect(record!.status, ObservanceStatus.observed);
      expect(record.fastingMethod, FastingMethod.waterOnly);
      expect(record.note, 'Felt very peaceful');
    });

    test('Duplicate protection: updating same occurrence edits record without creating duplicates', () async {
      // First save: Observed
      await service.recordVrat(
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2026-01-14',
        ekadashiName: 'Shattila Ekadashi',
        status: ObservanceStatus.observed,
        occurrences: mockOccurrences,
      );
      expect(service.getAllRecords().length, 1);

      // Second save: Edit to Partial
      await service.recordVrat(
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2026-01-14',
        ekadashiName: 'Shattila Ekadashi',
        status: ObservanceStatus.partial,
        fastingMethod: FastingMethod.fruitsMilk,
        note: 'Had milk in evening',
        occurrences: mockOccurrences,
      );

      // Should still be only 1 record, updated
      expect(service.getAllRecords().length, 1);
      final updated = service.getRecord(1);
      expect(updated!.status, ObservanceStatus.partial);
      expect(updated.fastingMethod, FastingMethod.fruitsMilk);
      expect(updated.note, 'Had milk in evening');
    });

    test('Delete record removes from history without modifying occurrences', () async {
      await service.recordVrat(
        ekadashiOccurrenceId: 2,
        ekadashiDate: '2026-01-29',
        ekadashiName: 'Jaya Ekadashi',
        status: ObservanceStatus.observed,
        occurrences: mockOccurrences,
      );
      expect(service.getAllRecords().length, 1);

      await service.deleteVrat(ekadashiOccurrenceId: 2, occurrences: mockOccurrences);
      expect(service.getAllRecords().length, 0);
      expect(service.getRecord(2), isNull);
      // Original mock occurrence remains intact
      expect(mockOccurrences.length, 25);
    });

    test('Backdating: past Ekadashis can be recorded historically', () async {
      await service.recordVrat(
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2025-09-24',
        ekadashiName: 'Indira Ekadashi',
        status: ObservanceStatus.observed,
        occurrences: mockOccurrences,
      );

      final record = service.getRecord(1);
      expect(record, isNotNull);
      expect(record!.ekadashiDate, '2025-09-24');
      expect(record.status, ObservanceStatus.observed);
    });
  });

  group('Module 04: VratStatisticsService & Streak Logic', () {
    test('Calculates current streak and longest streak accurately', () {
      final occurrences = [
        EkadashiDate(
          id: 1,
          name: 'Ekadashi 1',
          date: DateTime(2026, 1, 1),
          fastStartTime: '', fastBreakTime: '', description: '',
        ),
        EkadashiDate(
          id: 2,
          name: 'Ekadashi 2',
          date: DateTime(2026, 1, 15),
          fastStartTime: '', fastBreakTime: '', description: '',
        ),
        EkadashiDate(
          id: 3,
          name: 'Ekadashi 3',
          date: DateTime(2026, 2, 1),
          fastStartTime: '', fastBreakTime: '', description: '',
        ),
        EkadashiDate(
          id: 4,
          name: 'Ekadashi 4',
          date: DateTime(2026, 2, 15),
          fastStartTime: '', fastBreakTime: '', description: '',
        ),
      ];

      final Map<int, VratHistory> history = {
        1: const VratHistory(
          id: '1', ekadashiOccurrenceId: 1, ekadashiDate: '2026-01-01',
          ekadashiName: 'Ekadashi 1', status: ObservanceStatus.observed,
          recordedAtUTC: '', updatedAtUTC: '',
        ),
        2: const VratHistory(
          id: '2', ekadashiOccurrenceId: 2, ekadashiDate: '2026-01-15',
          ekadashiName: 'Ekadashi 2', status: ObservanceStatus.observed,
          recordedAtUTC: '', updatedAtUTC: '',
        ),
        3: const VratHistory(
          id: '3', ekadashiOccurrenceId: 3, ekadashiDate: '2026-02-01',
          ekadashiName: 'Ekadashi 3', status: ObservanceStatus.observed,
          recordedAtUTC: '', updatedAtUTC: '',
        ),
      };

      // As of 2026-02-05: 3 consecutive observed Ekadashis
      final streak = VratStatisticsService.calculateCurrentStreak(
        occurrences: occurrences,
        historyByOccurrenceId: history,
        asOfDate: DateTime(2026, 2, 5),
      );
      expect(streak, 3);

      final longest = VratStatisticsService.calculateLongestStreak(
        occurrences: occurrences,
        historyByOccurrenceId: history,
      );
      expect(longest, 3);
    });

    test('Missed observance breaks streak', () {
      final occurrences = [
        EkadashiDate(id: 1, name: 'E1', date: DateTime(2026, 1, 1), fastStartTime: '', fastBreakTime: '', description: ''),
        EkadashiDate(id: 2, name: 'E2', date: DateTime(2026, 1, 15), fastStartTime: '', fastBreakTime: '', description: ''),
        EkadashiDate(id: 3, name: 'E3', date: DateTime(2026, 2, 1), fastStartTime: '', fastBreakTime: '', description: ''),
      ];

      final Map<int, VratHistory> history = {
        1: const VratHistory(id: '1', ekadashiOccurrenceId: 1, ekadashiDate: '2026-01-01', ekadashiName: 'E1', status: ObservanceStatus.observed, recordedAtUTC: '', updatedAtUTC: ''),
        2: const VratHistory(id: '2', ekadashiOccurrenceId: 2, ekadashiDate: '2026-01-15', ekadashiName: 'E2', status: ObservanceStatus.missed, recordedAtUTC: '', updatedAtUTC: ''),
        3: const VratHistory(id: '3', ekadashiOccurrenceId: 3, ekadashiDate: '2026-02-01', ekadashiName: 'E3', status: ObservanceStatus.observed, recordedAtUTC: '', updatedAtUTC: ''),
      };

      final currentStreak = VratStatisticsService.calculateCurrentStreak(
        occurrences: occurrences,
        historyByOccurrenceId: history,
        asOfDate: DateTime(2026, 2, 5),
      );
      // Because E2 was missed, current streak is only E3 (1)
      expect(currentStreak, 1);

      // Longest streak was 1
      final longestStreak = VratStatisticsService.calculateLongestStreak(
        occurrences: occurrences,
        historyByOccurrenceId: history,
      );
      expect(longestStreak, 1);
    });

    test('Annual completion percentage uses dynamic denominator from Module 10', () {
      final mockOccurrences = generateMockEkadashis(year: 2026, count: 25);
      final Map<int, VratHistory> history = {};

      // Record 5 observed and 2 partial
      for (int i = 1; i <= 5; i++) {
        history[i] = VratHistory(
          id: '$i', ekadashiOccurrenceId: i, ekadashiDate: '2026-01-$i',
          ekadashiName: 'E$i', status: ObservanceStatus.observed,
          recordedAtUTC: '', updatedAtUTC: '',
        );
      }
      history[6] = const VratHistory(id: '6', ekadashiOccurrenceId: 6, ekadashiDate: '2026-02-01', ekadashiName: 'E6', status: ObservanceStatus.partial, recordedAtUTC: '', updatedAtUTC: '');
      history[7] = const VratHistory(id: '7', ekadashiOccurrenceId: 7, ekadashiDate: '2026-02-15', ekadashiName: 'E7', status: ObservanceStatus.missed, recordedAtUTC: '', updatedAtUTC: '');

      final stats = VratStatisticsService.calculateAnnualStats(
        year: 2026,
        occurrences: mockOccurrences,
        historyByOccurrenceId: history,
      );

      expect(stats.totalOccurrences, 25); // Dynamic denominator from occurrences
      expect(stats.observedCount, 5);
      expect(stats.partialCount, 1);
      expect(stats.missedCount, 1);
      expect(stats.unrecordedCount, 18);
      // 5 / 25 * 100 = 20.0%
      expect(stats.completionPercentage, 20.0);
    });
  });

  group('Module 04: AchievementEvaluator & Milestones', () {
    test('Evaluates all 6 milestones accurately', () {
      final mockOccurrences = generateMockEkadashis(year: 2026, count: 25);
      final List<VratHistory> history = [];

      // 1. Initially none unlocked
      final initEval = AchievementEvaluator.evaluate(
        history: history,
        occurrences: mockOccurrences,
        currentAchievements: {},
      );
      expect(initEval.updatedAchievements.values.every((a) => !a.isUnlocked), isTrue);

      // 2. Add 1 Observed -> unlocks First Vrat
      history.add(const VratHistory(
        id: '1', ekadashiOccurrenceId: 1, ekadashiDate: '2026-01-01',
        ekadashiName: 'E1', status: ObservanceStatus.observed,
        recordedAtUTC: '', updatedAtUTC: '',
      ));

      final firstEval = AchievementEvaluator.evaluate(
        history: history,
        occurrences: mockOccurrences,
        currentAchievements: initEval.updatedAchievements,
      );
      expect(firstEval.newlyUnlocked.any((a) => a.id == 'first_vrat'), isTrue);
      expect(firstEval.updatedAchievements['first_vrat']?.isUnlocked, isTrue);

      // 3. Add 4 more (total 5 consecutive) -> unlocks 5 Ekadashis AND Consistent Observance (>=3)
      for (int i = 2; i <= 5; i++) {
        history.add(VratHistory(
          id: '$i', ekadashiOccurrenceId: i, ekadashiDate: '2026-0$i-01',
          ekadashiName: 'E$i', status: ObservanceStatus.observed,
          recordedAtUTC: '', updatedAtUTC: '',
        ));
      }

      final fiveEval = AchievementEvaluator.evaluate(
        history: history,
        occurrences: mockOccurrences,
        currentAchievements: firstEval.updatedAchievements,
      );
      expect(fiveEval.newlyUnlocked.any((a) => a.id == 'vrat_5'), isTrue);
      expect(fiveEval.newlyUnlocked.any((a) => a.id == 'consistent_observance'), isTrue);
      expect(fiveEval.updatedAchievements['vrat_5']?.isUnlocked, isTrue);
      expect(fiveEval.updatedAchievements['consistent_observance']?.isUnlocked, isTrue);

      // 4. Test Next Milestone resolution
      final nextMilestone = AchievementEvaluator.getNextMilestone(
        userAchievements: fiveEval.updatedAchievements,
        totalObserved: 5,
        longestStreak: 5,
      );
      expect(nextMilestone?.achievement.id, 'vrat_10');
      expect(nextMilestone?.currentProgress, 5);
      expect(nextMilestone?.target, 10);
    });

    test('Retroactive evaluation unlocks newly satisfied milestones on backfilling', () {
      final mockOccurrences = generateMockEkadashis(year: 2026, count: 25);
      final List<VratHistory> history = [];

      // User starts with 2 records
      for (int i = 1; i <= 2; i++) {
        history.add(VratHistory(
          id: '$i', ekadashiOccurrenceId: i, ekadashiDate: '2026-0$i-01',
          ekadashiName: 'E$i', status: ObservanceStatus.observed,
          recordedAtUTC: '', updatedAtUTC: '',
        ));
      }

      final step1 = AchievementEvaluator.evaluate(
        history: history,
        occurrences: mockOccurrences,
        currentAchievements: {},
      );
      expect(step1.updatedAchievements['vrat_10']?.isUnlocked, isFalse);

      // User backfills 8 historical records -> total 10!
      for (int i = 3; i <= 10; i++) {
        history.add(VratHistory(
          id: '$i', ekadashiOccurrenceId: i, ekadashiDate: '2026-0$i-01',
          ekadashiName: 'E$i', status: ObservanceStatus.observed,
          recordedAtUTC: '', updatedAtUTC: '',
        ));
      }

      final step2 = AchievementEvaluator.evaluate(
        history: history,
        occurrences: mockOccurrences,
        currentAchievements: step1.updatedAchievements,
      );
      expect(step2.newlyUnlocked.any((a) => a.id == 'vrat_10'), isTrue);
      expect(step2.updatedAchievements['vrat_10']?.isUnlocked, isTrue);
    });
  });
}
