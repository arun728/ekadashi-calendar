import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/data/calendar_entry_repository.dart';
import 'package:ekadashi_calendar/data/sqflite_calendar_entry_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late CalendarEntryRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repo = SqfliteCalendarEntryRepository(inMemory: true);
    await repo.init();
  });

  tearDown(() async {
    if (repo is SqfliteCalendarEntryRepository) {
      await (repo as SqfliteCalendarEntryRepository).close();
    }
  });

  CalendarEntry custom({
    String id = 'c1',
    String title = 'Custom',
    DateTime? start,
  }) {
    final s = start ?? DateTime(2027, 8, 9, 10, 0);
    return CalendarEntry(
      id: id,
      title: title,
      startAt: s,
      endAt: s.add(const Duration(hours: 1)),
      source: CalendarEntrySource.custom,
      updatedAt: DateTime(2027, 1, 1),
    );
  }

  CalendarEntry google({
    String id = 'g1',
    String eventId = 'gev1',
    String title = 'Google event',
    DateTime? start,
  }) {
    final s = start ?? DateTime(2027, 8, 9, 14, 0);
    return CalendarEntry(
      id: id,
      title: title,
      startAt: s,
      endAt: s.add(const Duration(hours: 1)),
      source: CalendarEntrySource.google,
      googleEventId: eventId,
      calendarName: 'My calendar',
      updatedAt: DateTime(2027, 1, 1),
    );
  }

  test('upsert and getAll custom entry', () async {
    await repo.upsert(custom());
    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.first.title, 'Custom');
    expect(all.first.source, CalendarEntrySource.custom);
  });

  test('getForDay returns only that day', () async {
    await repo.upsert(custom(start: DateTime(2027, 8, 9, 9, 0)));
    await repo.upsert(custom(id: 'c2', title: 'Other', start: DateTime(2027, 8, 10, 9, 0)));
    final day = await repo.getForDay(DateTime(2027, 8, 9));
    expect(day.length, 1);
    expect(day.first.id, 'c1');
  });

  test('getBySource separates custom and google', () async {
    await repo.upsert(custom());
    await repo.upsert(google());
    final c = await repo.getBySource(CalendarEntrySource.custom);
    final g = await repo.getBySource(CalendarEntrySource.google);
    expect(c.length, 1);
    expect(g.length, 1);
    expect(g.first.googleEventId, 'gev1');
  });

  test('delete removes custom entry', () async {
    await repo.upsert(custom());
    await repo.delete('c1');
    expect(await repo.getAll(), isEmpty);
  });

  test('upsertGoogleBatch replaces by google_event_id', () async {
    await repo.upsert(google(title: 'Old'));
    await repo.upsertGoogleBatch([
      google(title: 'New title'),
    ]);
    final g = await repo.getBySource(CalendarEntrySource.google);
    expect(g.length, 1);
    expect(g.first.title, 'New title');
  });

  test('clearGoogleEntries does not delete custom', () async {
    await repo.upsert(custom());
    await repo.upsert(google());
    await repo.clearGoogleEntries();
    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.first.source, CalendarEntrySource.custom);
  });

  test('custom and google coexist on same day', () async {
    await repo.upsert(custom(start: DateTime(2027, 6, 14, 8, 0)));
    await repo.upsert(google(start: DateTime(2027, 6, 14, 12, 0)));
    final day = await repo.getForDay(DateTime(2027, 6, 14));
    expect(day.length, 2);
    expect(day.map((e) => e.source).toSet(), {
      CalendarEntrySource.custom,
      CalendarEntrySource.google,
    });
  });
}
