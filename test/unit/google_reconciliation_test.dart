import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ekadashi_calendar/data/sqflite_calendar_entry_repository.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/services/google_calendar_service.dart';
import 'package:ekadashi_calendar/services/google_event_mapper.dart';

class FakeGoogle extends GoogleAuthGateway {
  String? account = 'account-a';
  bool fail = false;
  List<Map<String, dynamic>> events = [];
  DateTime? min, max;
  @override
  Future<String?> accountId() async => account;
  @override
  Future<bool> isSignedIn() async => account != null;
  @override
  Future<bool> signIn() async => account != null;
  @override
  Future<void> signOut() async {
    account = null;
  }

  /// The free-sync marker stored in this Google account (Drive app data).
  DateTime? freeSyncMarker;
  @override
  Future<bool> freeSyncUsed() async => freeSyncMarker != null;
  @override
  Future<void> markFreeSyncUsed(DateTime month) async => freeSyncMarker = month;

  @override
  Future<List<GoogleCalendarInfo>> listCalendars() async => [];
  @override
  Future<List<Map<String, dynamic>>> fetchEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    required List<String> calendarIds,
  }) async {
    min = timeMin;
    max = timeMax;
    if (fail) throw StateError('Page two failed');
    return events;
  }
}

Map<String, dynamic> event(
  String id, {
  String calendar = 'primary',
  String start = '2027-01-01',
  String end = '2027-01-02',
}) => {
  'id': id,
  'calendarId': calendar,
  'summary': id,
  'start': {'date': start},
  'end': {'date': end},
};
CalendarEntry imported(
  String account,
  String calendar,
  String id,
  String date,
) => GoogleEventMapper.fromApiEvent({
  ...event(
    id,
    calendar: calendar,
    start: date,
    end: DateTime.parse(
      date,
    ).add(const Duration(days: 1)).toIso8601String().substring(0, 10),
  ),
  'accountId': account,
})!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late SqfliteCalendarEntryRepository repo;
  late FakeGoogle auth;
  late GoogleCalendarService service;
  Future<int> sync() => service.syncImport(
    timeMin: DateTime(2027),
    timeMax: DateTime(2028),
    calendarIds: ['primary'],
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = SqfliteCalendarEntryRepository(inMemory: true);
    await repo.init();
    auth = FakeGoogle();
    service = GoogleCalendarService(auth: auth, repository: repo);
  });
  tearDown(() async => repo.close());
  test(
    'Reimport removes events deleted on Google, including an empty year',
    () async {
      auth.events = [
        event('January'),
        event('December', start: '2027-12-31', end: '2028-01-01'),
      ];
      expect(await sync(), 2);
      auth.events = [event('December', start: '2027-12-31', end: '2028-01-01')];
      expect(await sync(), 1);
      expect((await repo.getAll()).map((e) => e.title), ['December']);
      auth.events = [];
      await sync();
      expect(await repo.getAll(), isEmpty);
      expect(auth.min, DateTime(2027));
      expect(auth.max, DateTime(2028));
    },
  );
  test('Repeated imports update one event without duplicates', () async {
    auth.events = [event('a')];
    await sync();
    auth.events = [
      {...event('a'), 'summary': 'Changed'},
    ];
    await sync();
    await sync();
    expect(await repo.getAll(), hasLength(1));
    expect((await repo.getAll()).single.title, 'Changed');
  });
  test('Failed fetch preserves previous cache and custom notes', () async {
    auth.events = [event('a')];
    await sync();
    await repo.upsert(
      CalendarEntry(
        id: 'custom',
        title: 'Private',
        notes: 'Keep',
        startAt: DateTime(2027),
        endAt: DateTime(2027, 1, 2),
        isAllDay: true,
        source: CalendarEntrySource.custom,
        updatedAt: DateTime(2027),
      ),
    );
    auth.fail = true;
    await expectLater(sync(), throwsStateError);
    expect((await repo.getAll()).map((e) => e.id), contains('custom'));
    expect(await repo.getBySource(CalendarEntrySource.google), hasLength(1));
  });
  test(
    'Account, calendar and year isolation survives deletion reconciliation',
    () async {
      for (final e in [
        imported('account-b', 'primary', 'same', '2027-02-01'),
        imported('account-a', 'holidays', 'same', '2027-02-01'),
        imported('account-a', 'primary', 'old-year', '2026-02-01'),
        imported('account-a', 'primary', 'same', '2027-02-01'),
      ]) {
        await repo.upsert(e);
      }
      await sync();
      final remaining = await repo.getAll();
      expect(remaining, hasLength(3));
      expect(remaining.where((e) => e.startAt.year == 2026), hasLength(1));
      expect(remaining.where((e) => e.accountId == 'account-b'), hasLength(1));
      expect(remaining.where((e) => e.calendarId == 'holidays'), hasLength(1));
    },
  );
  test(
    'Cancelled event removes cached occurrence; signout removes only that account',
    () async {
      auth.events = [event('a')];
      await sync();
      await repo.upsert(imported('account-b', 'primary', 'b', '2027-01-01'));
      auth.events = [
        {...event('a'), 'status': 'cancelled'},
      ];
      await sync();
      expect((await repo.getAll()).single.accountId, 'account-b');
      auth.events = [event('a')];
      await sync();
      await service.signOut();
      expect((await repo.getAll()).single.accountId, 'account-b');
    },
  );
  test(
    'Malformed Google event aborts reconciliation without deleting valid cache',
    () async {
      auth.events = [event('a')];
      await sync();
      auth.events = [
        {
          ...event('b'),
          'end': {'date': '2026-01-01'},
        },
      ];
      await expectLater(sync(), throwsFormatException);
      expect((await repo.getAll()).single.title, 'a');
    },
  );
  test('Google exclusive end excludes the next day and exact midnight', () {
    final allDay = imported('account-a', 'primary', 'all', '2027-01-01');
    expect(allDay.occursOn(DateTime(2027, 1, 1)), isTrue);
    expect(allDay.occursOn(DateTime(2027, 1, 2)), isFalse);
    final timed = GoogleEventMapper.fromApiEvent({
      'id': 'night',
      'calendarId': 'primary',
      'accountId': 'account-a',
      'start': {'dateTime': '2027-01-01T23:00:00Z'},
      'end': {'dateTime': '2027-01-02T00:00:00Z'},
    })!;
    expect(timed.occursOn(DateTime(2027, 1, 2)), isFalse);
  });
}
