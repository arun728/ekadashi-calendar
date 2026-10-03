import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/data/calendar_repository.dart';
import 'package:ekadashi_calendar/data/tracker_history_store.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';

class Packs implements CalendarDataSource {
  List<Map<String, dynamic>> packs;
  Packs(this.packs);
  @override
  Future<List<Map<String, dynamic>>> loadYearPacks() async => packs;
}

Map<String, dynamic> savedRow(int year, int id, {String? uid}) => VratHistory(
  id: 'record-$year-$id',
  ekadashiOccurrenceId: id,
  occurrenceUid: uid,
  ekadashiDate: '$year-01-01',
  ekadashiName: 'Event',
  status: ObservanceStatus.observed,
  note: 'Private note',
  timezone: 'EST',
  tradition: 'Vaishnava',
  locationContext: 'Boston',
  recordedAtUTC: '$year-01-01T12:00:00Z',
  updatedAtUTC: '$year-01-01T12:00:00Z',
).toJson();
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EkadashiService();
  setUpAll(() async => service.initializeData());
  setUp(() => SharedPreferences.setMockInitialValues({}));
  List<EkadashiDate> events() =>
      service.getEkadashis(timezone: 'IST', languageCode: 'en');
  test('Both years retain their own ID 1, data and cache', () {
    final old = service.getEkadashis(
      timezone: 'IST',
      languageCode: 'en',
      year: 2026,
    );
    final newer = service.getEkadashis(
      timezone: 'IST',
      languageCode: 'te',
      year: 2027,
    );
    expect(old, hasLength(24));
    expect(newer, hasLength(24));
    expect(old.first.id, 1);
    expect(newer.first.id, 2027001);
    expect(old.first.occurrenceUid, 'ekadashi:2026:01');
    expect(newer.first.occurrenceUid, 'ekadashi:2027:01');
    expect(old.first.name, contains('Shattila'));
    expect(newer.first.usesContentFallback, isFalse);
    expect(
      service
          .getEkadashis(timezone: 'IST', languageCode: 'te', year: 2026)
          .every((e) => !e.usesContentFallback),
      isTrue,
    );
    expect(events(), hasLength(48));
  });
  test(
    'Migration retains both legacy ID 1 records, notes and achievement markers',
    () async {
      final raw = jsonEncode([savedRow(2026, 1), savedRow(2027, 1)]);
      SharedPreferences.setMockInitialValues({
        'vrat_tracker_enabled': true,
        'vrat_tracker_history': raw,
        'vrat_tracker_notified_achievements': ['first_vrat'],
      });
      final tracker = VratTrackerService();
      await tracker.init(occurrences: events());
      expect(tracker.getAllRecords(), hasLength(2));
      expect(tracker.getRecordByUid('ekadashi:2026:01')?.note, 'Private note');
      expect(
        tracker.getRecordByUid('ekadashi:2027:01')?.locationContext,
        'Boston',
      );
      expect(tracker.getRecord(2027001)?.tradition, 'Vaishnava');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vrat_tracker_history'), raw);
      expect(prefs.getStringList('vrat_tracker_notified_achievements'), [
        'first_vrat',
      ]);
      final first = prefs.getString(TrackerHistoryStore.key);
      final restored = VratTrackerService();
      await restored.init(occurrences: events());
      expect(restored.getAllRecords(), hasLength(2));
      expect(prefs.getString(TrackerHistoryStore.key), first);
      final backup =
          jsonDecode(prefs.getString(TrackerHistoryStore.backupKey)!) as Map;
      expect(backup['vrat_tracker_history'], raw);
    },
  );
  test('Unknown and duplicate records are preserved in quarantine', () async {
    final valid = savedRow(2026, 1);
    final unknown = savedRow(2030, 1);
    SharedPreferences.setMockInitialValues({
      'vrat_tracker_history': jsonEncode([valid, unknown, valid]),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = TrackerHistoryStore();
    final loaded = await store.load(prefs, events());
    expect(loaded, hasLength(1));
    await store.save(prefs, loaded);
    final data = jsonDecode(prefs.getString(TrackerHistoryStore.key)!) as Map;
    expect(data['unresolved'], [unknown, valid]);
  });
  test(
    'Corrupt current storage disables recording and leaves original value intact',
    () async {
      SharedPreferences.setMockInitialValues({
        'vrat_tracker_enabled': true,
        TrackerHistoryStore.key: '{bad-json',
      });
      final tracker = VratTrackerService();
      await tracker.init(occurrences: events());
      expect(tracker.isInitialized, isFalse);
      expect(tracker.trackerEnabled, isFalse);
      expect(tracker.storageError, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(TrackerHistoryStore.key), '{bad-json');
    },
  );
  test(
    'Pack rejection is atomic and a repaired provider can be retried',
    () async {
      final original =
          jsonDecode(await rootBundle.loadString('assets/calendar/2026.json'))
              as Map<String, dynamic>;
      final broken = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      broken['ekadashis'][1]['notification_id'] = 1;
      final source = Packs([original, broken]);
      final repository = CalendarRepository(source: source);
      await expectLater(repository.load(), throwsFormatException);
      expect(repository.availableYears, isEmpty);
      source.packs = [original];
      await repository.load();
      expect(repository.availableYears, [2026]);
    },
  );
  test(
    'Published calendar cannot be corrupted by changing its returned adapter',
    () async {
      final repository = CalendarRepository();
      await repository.load();
      final first = repository.combinedData();
      (first['ekadashis'] as List).first['name']['en'] = 'Corrupted';
      final second = repository.combinedData();
      expect(
        (second['ekadashis'] as List).first['name']['en'],
        isNot('Corrupted'),
      );
    },
  );
}
