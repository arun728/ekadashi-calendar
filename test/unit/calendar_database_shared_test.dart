import 'dart:io';

import 'package:ekadashi_calendar/data/sqflite_calendar_entry_repository.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The app's entries database is one shared connection (sqflite returns the
/// same open database for the same file). A Calendar screen that goes away
/// must not close it under the screen that replaced it: that left Google
/// import and custom entries failing with "database_closed" until the app
/// was restarted.
void main() {
  late Directory dir;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('entries_db');
  });
  tearDown(() => dir.delete(recursive: true));

  CalendarEntry entry(String id) => CalendarEntry(
    id: id,
    title: 'Temple visit',
    startAt: DateTime(2026, 10, 20, 9),
    endAt: DateTime(2026, 10, 20, 10),
    source: CalendarEntrySource.custom,
    updatedAt: DateTime(2026),
  );

  test('closing an old screen keeps the new screen\'s database open', () async {
    final path = p.join(dir.path, 'entries.db');
    final old = SqfliteCalendarEntryRepository(path: path);
    await old.init();
    // The new screen opens before the old one is disposed.
    final current = SqfliteCalendarEntryRepository(path: path);
    await current.init();
    await old.close();
    await current.upsert(entry('e1'));
    expect((await current.getAll()).map((e) => e.id), ['e1']);
  });

  test('a database closed elsewhere is opened again on the next use', () async {
    final path = p.join(dir.path, 'entries.db');
    final repo = SqfliteCalendarEntryRepository(path: path);
    await repo.init();
    await (await databaseFactory.openDatabase(path)).close();
    await repo.upsert(entry('e2'));
    expect((await repo.getAll()).map((e) => e.id), ['e2']);
  });
}
