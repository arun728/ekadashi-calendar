import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ekadashi_calendar/data/sqflite_calendar_entry_repository.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/services/fake_google_auth_gateway.dart';
import 'package:ekadashi_calendar/services/google_calendar_service.dart';

void main() {
  late SqfliteCalendarEntryRepository repo;
  late FakeGoogleAuthGateway auth;
  late GoogleCalendarService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repo = SqfliteCalendarEntryRepository(inMemory: true);
    await repo.init();
    auth = FakeGoogleAuthGateway(
      events: [
        {
          'id': 'g1',
          'summary': 'Team offsite',
          'start': {'dateTime': '2027-08-09T10:00:00+05:30'},
          'end': {'dateTime': '2027-08-09T12:00:00+05:30'},
        },
        {
          'id': 'g2',
          'summary': 'Holiday',
          'start': {'date': '2027-08-15'},
          'end': {'date': '2027-08-16'},
        },
      ],
    );
    service = GoogleCalendarService(auth: auth, repository: repo);
  });

  tearDown(() async {
    await repo.close();
  });

  test('syncImport signs in and stores Google entries', () async {
    expect(await service.isSignedIn(), isFalse);
    final count = await service.syncImport(
      timeMin: DateTime(2027, 8, 1),
      timeMax: DateTime(2027, 9, 1),
      calendarIds: ['primary'],
    );
    expect(count, 2);
    expect(await service.isSignedIn(), isTrue);
    final google = await repo.getBySource(CalendarEntrySource.google);
    expect(google.length, 2);
    expect(google.map((e) => e.title).toSet(), {'Team offsite', 'Holiday'});
  });

  test('syncImport does not remove custom entries', () async {
    await repo.upsert(CalendarEntry(
      id: 'c1',
      title: 'Custom only',
      startAt: DateTime(2027, 8, 9, 8, 0),
      endAt: DateTime(2027, 8, 9, 9, 0),
      source: CalendarEntrySource.custom,
      updatedAt: DateTime.now(),
    ));
    await service.syncImport(
      timeMin: DateTime(2027, 8, 1),
      timeMax: DateTime(2027, 9, 1),
    );
    final all = await repo.getAll();
    expect(all.any((e) => e.source == CalendarEntrySource.custom), isTrue);
    expect(all.where((e) => e.source == CalendarEntrySource.google).length, 2);
  });

  test('failed sign-in imports nothing', () async {
    auth.failSignIn = true;
    final count = await service.syncImport(
      timeMin: DateTime(2027, 8, 1),
      timeMax: DateTime(2027, 9, 1),
      calendarIds: ['primary'],
    );
    expect(count, 0);
    expect(await repo.getAll(), isEmpty);
  });

  test('signOut clears session flag', () async {
    await service.signIn();
    expect(await service.isSignedIn(), isTrue);
    await service.signOut();
    expect(await service.isSignedIn(), isFalse);
  });
}
