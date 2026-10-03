import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/calendar_entry.dart';
import 'calendar_entry_repository.dart';

class SqfliteCalendarEntryRepository implements CalendarEntryRepository {
  SqfliteCalendarEntryRepository({this.inMemory = false, this.debugName});

  final bool inMemory;
  final String? debugName;
  Database? _db;
  Future<void>? _initializing;

  static const _table = 'calendar_entries';
  static int _memCounter = 0;

  @override
  Future<void> init() => _initializing ??= _open().catchError((Object error) {
    _initializing = null;
    throw error;
  });

  Future<void> _open() async {
    if (_db != null) return;
    if (inMemory) {
      _memCounter++;
      // Unique path so tests do not share state
      final name =
          debugName ??
          p.join(Directory.systemTemp.path, 'ek_cal_test_$_memCounter.db');
      try {
        await deleteDatabase(name);
      } catch (_) {}
      _db = await openDatabase(
        name,
        version: 2,
        onUpgrade: _onUpgrade,
        onCreate: _onCreate,
        singleInstance: false,
      );
    } else {
      final dbPath = await getDatabasesPath();
      _db = await openDatabase(
        p.join(dbPath, 'ekadashi_calendar_entries.db'),
        version: 2,
        onUpgrade: _onUpgrade,
        onCreate: _onCreate,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        notes TEXT,
        start_at TEXT NOT NULL,
        end_at TEXT NOT NULL,
        is_all_day INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL,
        google_event_id TEXT,
        calendar_name TEXT,
        account_id TEXT,
        calendar_id TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_entries_start ON $_table(start_at)');
    await db.execute('CREATE INDEX idx_entries_source ON $_table(source)');
  }

  Future<void> _onUpgrade(Database db, int old, int version) async {
    if (old < 2) {
      await db.execute('ALTER TABLE $_table ADD COLUMN account_id TEXT');
      await db.execute('ALTER TABLE $_table ADD COLUMN calendar_id TEXT');
      // Imported rows without account attribution must not leak to a new account.
      await db.delete(_table, where: 'source = ?', whereArgs: ['google']);
      final rows = await db.query(_table, where: 'is_all_day = 1');
      for (final row in rows) {
        final date = DateTime.parse(row['end_at'] as String);
        await db.update(
          _table,
          {
            'end_at': DateTime(
              date.year,
              date.month,
              date.day + 1,
            ).toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('CalendarEntryRepository not initialized');
    }
    return d;
  }

  @override
  Future<List<CalendarEntry>> getAll() async {
    final rows = await db.query(_table, orderBy: 'start_at ASC');
    return rows.map(CalendarEntry.fromMap).toList();
  }

  @override
  Future<List<CalendarEntry>> getForDay(DateTime day) async {
    final all = await getAll();
    return all.where((e) => e.occursOn(day)).toList();
  }

  @override
  Future<List<CalendarEntry>> getBySource(CalendarEntrySource source) async {
    final rows = await db.query(
      _table,
      where: 'source = ?',
      whereArgs: [source.name],
      orderBy: 'start_at ASC',
    );
    return rows.map(CalendarEntry.fromMap).toList();
  }

  @override
  Future<void> upsert(CalendarEntry entry) async {
    await db.insert(
      _table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteByGoogleEventId(String googleEventId) async {
    await db.delete(
      _table,
      where: 'google_event_id = ?',
      whereArgs: [googleEventId],
    );
  }

  @override
  Future<void> upsertGoogleBatch(List<CalendarEntry> entries) async {
    final batch = db.batch();
    for (final e in entries) {
      batch.insert(
        _table,
        e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> clearGoogleEntries({String? accountId}) async {
    await db.delete(
      _table,
      where: accountId == null ? 'source = ?' : 'source = ? AND account_id = ?',
      whereArgs: [
        CalendarEntrySource.google.name,
        if (accountId != null) accountId,
      ],
    );
  }

  @override
  Future<void> replaceGoogleWindow({
    required String accountId,
    required List<String> calendarIds,
    required DateTime timeMin,
    required DateTime timeMax,
    required List<CalendarEntry> entries,
  }) async {
    for (final entry in entries) {
      if (entry.source != CalendarEntrySource.google ||
          entry.accountId != accountId ||
          !calendarIds.contains(entry.calendarId)) {
        throw ArgumentError('Import scope does not match event');
      }
    }
    await db.transaction((txn) async {
      final rows = await txn.query(
        _table,
        where: 'source = ? AND account_id = ?',
        whereArgs: ['google', accountId],
      );
      for (final row in rows) {
        final entry = CalendarEntry.fromMap(row);
        if (calendarIds.contains(entry.calendarId) &&
            entry.startAt.isBefore(timeMax) &&
            entry.endAt.isAfter(timeMin)) {
          await txn.delete(_table, where: 'id = ?', whereArgs: [entry.id]);
        }
      }
      for (final entry in entries) {
        await txn.insert(
          _table,
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> close() async {
    if (_initializing != null) await _initializing;
    await _db?.close();
    _db = null;
    _initializing = null;
  }
}
