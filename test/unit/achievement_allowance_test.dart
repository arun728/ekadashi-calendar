import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/services/achievement_evaluator.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';

List<EkadashiDate> events() => List.generate(
  12,
  (i) => EkadashiDate(
    id: i + 1,
    name: 'Event ${i + 1}',
    date: DateTime(2025, 1, i + 1),
    fastStartTime: '',
    fastBreakTime: '',
    description: '',
  ),
);
List<VratHistory> history(int count) => List.generate(
  count,
  (i) => VratHistory(
    id: '$i',
    ekadashiOccurrenceId: i + 1,
    occurrenceUid: events()[i].occurrenceUid,
    ekadashiDate: '2025-01-${(i + 1).toString().padLeft(2, '0')}',
    ekadashiName: '',
    status: ObservanceStatus.observed,
    recordedAtUTC: '2025-02-01T00:00:00Z',
    updatedAtUTC: '2025-02-01T00:00:00Z',
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Allowance counts earned badges; an early streak can be a free unlock',
    () {
      var state = <String, UserAchievement>{};
      for (final count in [1, 3, 5, 12]) {
        final remaining = (3 - state.values.where((a) => a.isUnlocked).length)
            .clamp(0, 3);
        final result = AchievementEvaluator.evaluate(
          history: history(count),
          occurrences: events(),
          currentAchievements: state,
          newUnlockLimit: remaining,
        );
        state = result.updatedAchievements;
      }
      expect(
        state.entries
            .where((e) => e.value.isUnlocked)
            .map((e) => e.key)
            .toSet(),
        {'first_vrat', 'consistent_observance', 'vrat_5'},
      );
      expect(state['vrat_12']?.progressValue, 12);
      expect(state['vrat_12']?.isUnlocked, isFalse);
    },
  );
  test('Grandfathered badges survive a zero new-unlock allowance', () {
    final full = AchievementEvaluator.evaluate(
      history: history(12),
      occurrences: events(),
      currentAchievements: {},
    );
    final downgraded = AchievementEvaluator.evaluate(
      history: [],
      occurrences: events(),
      currentAchievements: full.updatedAchievements,
      newUnlockLimit: 0,
    );
    expect(
      downgraded.updatedAchievements.values.where((a) => a.isUnlocked).length,
      6,
    );
    expect(downgraded.newlyUnlocked, isEmpty);
  });
  test(
    'Premium upgrade unlocks accumulated progress once; downgrade keeps badges',
    () async {
      var premium = false;
      final tracker = VratTrackerService(premiumAchievements: () => premium);
      await tracker.init(occurrences: events());
      for (final event in events()) {
        await tracker.recordVrat(
          ekadashiOccurrenceId: event.id,
          occurrenceUid: event.occurrenceUid,
          ekadashiDate: event.date.toIso8601String().substring(0, 10),
          ekadashiName: event.name,
          status: ObservanceStatus.observed,
          occurrences: events(),
        );
      }
      expect(
        tracker.userAchievements.values.where((a) => a.isUnlocked).length,
        3,
      );
      premium = true;
      final unlocked = await tracker.refreshAchievements(events());
      expect(unlocked, hasLength(3));
      expect(await tracker.refreshAchievements(events()), isEmpty);
      premium = false;
      await tracker.refreshAchievements(events());
      expect(
        tracker.userAchievements.values.where((a) => a.isUnlocked).length,
        6,
      );
      final recreated = VratTrackerService();
      await recreated.init(occurrences: events());
      expect(
        recreated.userAchievements.values.where((a) => a.isUnlocked).length,
        6,
      );
    },
  );
}
