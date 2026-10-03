import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/data/tracker_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Opt-in cannot overwrite a corrupt history store', () async {
    SharedPreferences.setMockInitialValues({TrackerHistoryStore.key: 'broken'});
    final tracker = VratTrackerService();
    await tracker.init();
    await tracker.enableTracker();
    await tracker.recordVrat(
      ekadashiOccurrenceId: 1,
      ekadashiDate: '2026-01-01',
      ekadashiName: 'Event',
      status: ObservanceStatus.observed,
    );
    expect(tracker.trackerEnabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(TrackerHistoryStore.key), 'broken');
  });
}
