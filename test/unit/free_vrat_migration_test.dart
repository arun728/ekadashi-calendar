import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final previous in [null, false, true]) {
    test(
      'Vrat is free and available with legacy enabled preference $previous',
      () async {
        SharedPreferences.setMockInitialValues({
          if (previous != null) 'vrat_tracker_enabled': previous,
        });
        final tracker = VratTrackerService();
        await tracker.init();
        expect(tracker.trackerEnabled, isTrue);
        await tracker.recordVrat(
          ekadashiOccurrenceId: 1,
          occurrenceUid: 'ekadashi:2026:01',
          ekadashiDate: '2026-01-01',
          ekadashiName: 'First event',
          status: ObservanceStatus.observed,
        );
        expect(tracker.getRecordByUid('ekadashi:2026:01'), isNotNull);
        final recreated = VratTrackerService();
        await recreated.init();
        expect(
          recreated.getRecordByUid('ekadashi:2026:01')?.status,
          ObservanceStatus.observed,
        );
      },
    );
  }
  test(
    'Free migration preserves tracking start, earned badges and notification markers',
    () async {
      const started = '2026-02-01T12:30:00.000Z';
      const earned = UserAchievement(
        id: 'legacy',
        achievementId: 'full_year_observance',
        progressValue: 100,
        isUnlocked: true,
        unlockedAtUTC: started,
        lastEvaluatedAtUTC: started,
      );
      SharedPreferences.setMockInitialValues({
        'vrat_tracker_enabled': false,
        'vrat_tracker_enabled_at': started,
        'vrat_tracker_user_achievements': jsonEncode([earned.toJson()]),
        'vrat_tracker_notified_achievements': ['full_year_observance'],
      });
      final tracker = VratTrackerService();
      await tracker.init();
      expect(tracker.trackerEnabled, isTrue);
      expect(tracker.trackingEnabledAt?.toIso8601String(), started);
      expect(
        tracker.userAchievements['full_year_observance']?.toJson(),
        earned.toJson(),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('vrat_tracker_notified_achievements'), [
        'full_year_observance',
      ]);
    },
  );
}
