import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/services/achievement_evaluator.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/vrat_statistics_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';

List<EkadashiDate> events() => List.generate(
  24,
  (index) => EkadashiDate(
    id: index + 1,
    name: 'Event ${index + 1}',
    date: DateTime(2026, 1, index + 1),
    fastStartTime: '06:00 AM',
    fastBreakTime: '06:00 AM - 08:00 AM',
    description: 'Fixture',
  ),
);
VratHistory record(int id, ObservanceStatus status) => VratHistory(
  id: 'record_$id',
  ekadashiOccurrenceId: id,
  ekadashiDate: '2026-01-${id.toString().padLeft(2, '0')}',
  ekadashiName: 'Event $id',
  status: status,
  recordedAtUTC: '2026-01-25T00:00:00Z',
  updatedAtUTC: '2026-01-25T00:00:00Z',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final status in ObservanceStatus.values) {
    test(
      'History round-trip retains $status and location/tradition context',
      () {
        final original = record(1, status).copyWith(
          note: 'Private',
          tradition: 'Vaishnava',
          timezone: 'EST',
          locationContext: 'New York',
          fastingMethod: FastingMethod.waterOnly,
        );
        expect(
          VratHistory.fromJson(original.toJson()).toJson(),
          original.toJson(),
        );
      },
    );
  }
  for (final status in [
    ObservanceStatus.partial,
    ObservanceStatus.missed,
    ObservanceStatus.unrecorded,
  ]) {
    test('$status breaks a completed-event streak', () {
      final history = {
        1: record(1, ObservanceStatus.observed),
        2: record(2, status),
        3: record(3, ObservanceStatus.observed),
      };
      expect(
        VratStatisticsService.calculateCurrentStreak(
          occurrences: events().take(3).toList(),
          historyByOccurrenceId: history,
          asOfDate: DateTime(2026, 1, 4),
        ),
        1,
      );
      expect(
        VratStatisticsService.calculateLongestStreak(
          occurrences: events().take(3).toList(),
          historyByOccurrenceId: history,
        ),
        1,
      );
    });
  }
  test(
    'Unrecorded event today preserves previous streak until the next day',
    () {
      final history = {
        1: record(1, ObservanceStatus.observed),
        2: record(2, ObservanceStatus.observed),
      };
      expect(
        VratStatisticsService.calculateCurrentStreak(
          occurrences: events().take(3).toList(),
          historyByOccurrenceId: history,
          asOfDate: DateTime(2026, 1, 3),
        ),
        2,
      );
      expect(
        VratStatisticsService.calculateCurrentStreak(
          occurrences: events().take(3).toList(),
          historyByOccurrenceId: history,
          asOfDate: DateTime(2026, 1, 4),
        ),
        0,
      );
    },
  );
  test(
    'Empty year has zero completion and history-only years remain available',
    () {
      final stats = VratStatisticsService.calculateAnnualStats(
        year: 2027,
        occurrences: events(),
        historyByOccurrenceId: {},
      );
      expect(stats.totalOccurrences, 0);
      expect(stats.completionPercentage, 0);
      final years = VratStatisticsService.getAvailableYears(
        occurrences: events(),
        history: [
          record(
            1,
            ObservanceStatus.observed,
          ).copyWith(ekadashiDate: '2025-01-01'),
        ],
      );
      expect(years, containsAll([DateTime.now().year, 2025]));
      expect(
        years,
        orderedEquals(years.toSet().toList()..sort((a, b) => b.compareTo(a))),
      );
    },
  );
  test(
    'All six requirement milestones unlock and evaluation is idempotent',
    () {
      final history = List.generate(
        24,
        (index) => record(index + 1, ObservanceStatus.observed),
      );
      final first = AchievementEvaluator.evaluate(
        history: history,
        occurrences: events(),
        currentAchievements: {},
      );
      expect(first.newlyUnlocked.map((e) => e.id).toSet(), {
        'first_vrat',
        'vrat_5',
        'vrat_10',
        'vrat_12',
        'consistent_observance',
        'full_year_observance',
      });
      final again = AchievementEvaluator.evaluate(
        history: history,
        occurrences: events(),
        currentAchievements: first.updatedAchievements,
      );
      expect(again.newlyUnlocked, isEmpty);
      for (final id in first.updatedAchievements.keys) {
        expect(
          again.updatedAchievements[id]!.unlockedAtUTC,
          first.updatedAchievements[id]!.unlockedAtUTC,
        );
      }
    },
  );
  test('Earned achievements remain earned after editing history', () {
    final first = AchievementEvaluator.evaluate(
      history: [record(1, ObservanceStatus.observed)],
      occurrences: events(),
      currentAchievements: {},
    );
    final edited = AchievementEvaluator.evaluate(
      history: [record(1, ObservanceStatus.partial)],
      occurrences: events(),
      currentAchievements: first.updatedAchievements,
    );
    expect(edited.updatedAchievements['first_vrat']!.isUnlocked, isTrue);
    expect(edited.newlyUnlocked, isEmpty);
  });
  test(
    'History, private notes and one-time unlock survive service recreation',
    () async {
      final first = VratTrackerService();
      await first.init(occurrences: events());

      final firstUnlocks = await first.recordVrat(
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2026-01-01',
        ekadashiName: 'Event 1',
        status: ObservanceStatus.observed,
        note: 'Private',
        occurrences: events(),
      );
      expect(firstUnlocks.map((achievement) => achievement.id), ['first_vrat']);
      final recreated = VratTrackerService();
      await recreated.init(occurrences: events());
      expect(recreated.getRecord(1)!.note, 'Private');
      final repeatedUnlocks = await recreated.recordVrat(
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2026-01-01',
        ekadashiName: 'Event 1',
        status: ObservanceStatus.observed,
        note: 'Edited',
        occurrences: events(),
      );
      expect(recreated.getAllRecords(), hasLength(1));
      expect(repeatedUnlocks, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vrat_tracker_enabled', false);
      final disabled = VratTrackerService();
      await disabled.init(occurrences: events());
      expect(disabled.trackerEnabled, isTrue);
      expect(disabled.getRecord(1)!.note, 'Edited');
      expect(disabled.userAchievements['first_vrat']!.isUnlocked, isTrue);
    },
  );
  test(
    'Deletion persists across restart without modifying calendar events',
    () async {
      final service = VratTrackerService();
      await service.init(occurrences: events());

      await service.recordVrat(
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2026-01-01',
        ekadashiName: 'Event 1',
        status: ObservanceStatus.observed,
        occurrences: events(),
      );
      await service.deleteVrat(ekadashiOccurrenceId: 1, occurrences: events());
      final recreated = VratTrackerService();
      await recreated.init(occurrences: events());
      expect(recreated.getAllRecords(), isEmpty);
      expect(events(), hasLength(24));
    },
  );
}
