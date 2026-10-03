import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';

class FailingHistoryStore extends InMemorySharedPreferencesStore {
  FailingHistoryStore() : super.empty();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith('vrat_tracker_history_v2')) throw StateError('Disk full');
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Failed history save does not show an unsaved observance or unlock a milestone',
    () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = VratTrackerService();
      await tracker.init();
      await tracker.enableTracker();
      final original = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = FailingHistoryStore();
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = original;
      });
      await expectLater(
        tracker.recordVrat(
          ekadashiOccurrenceId: 1,
          ekadashiDate: '2026-01-01',
          ekadashiName: 'Event',
          status: ObservanceStatus.observed,
        ),
        throwsStateError,
      );
      expect(tracker.getAllRecords(), isEmpty);
    },
  );
  test(
    'Concurrent saves retain both records after a service restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = VratTrackerService();
      await tracker.init();
      await tracker.enableTracker();
      await Future.wait([
        for (final id in [1, 2])
          tracker.recordVrat(
            ekadashiOccurrenceId: id,
            ekadashiDate: '2026-01-01',
            ekadashiName: 'Event $id',
            status: ObservanceStatus.observed,
          ),
      ]);
      final restored = VratTrackerService();
      await restored.init();
      expect(restored.getAllRecords(), hasLength(2));
      expect(restored.getAllRecords().map((e) => e.occurrenceUid).toSet(), {
        'ekadashi:2026:01',
        'ekadashi:2026:02',
      });
    },
  );
}
