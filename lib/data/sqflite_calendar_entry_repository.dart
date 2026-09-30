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

  static const _table = 'calendar_entries';
  static int _memCounter = 0;

  @override
  Future<void> init() async {
    if (_db != null) return;
    if (inMemory) {
      _memCounter++;
      // Unique path so tests do not share state
      final name = debugName ??
          p.join(Directory.systemTemp.path, 'ek_cal_test_$_memCounter.db');
      try {
        await deleteDatabase(name);
      } catch (_) {}
      _db = await openDatabase(
        name,
        version: 1,
        onCreate: _onCreate,
        singleInstance: false,
      );
    } else {
      final dbPath = await getDatabasesPath();
      _db = await openDatabase(
        p.join(dbPath, 'ekadashi_calendar_entries.db'),
        version: 1,
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
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_entries_start ON $_table(start_at)',
    );
    await db.execute(
      'CREATE INDEX idx_entries_source ON $_table(source)',
    );
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
      if (e.googleEventId != null) {
        batch.delete(
          _table,
          where: 'google_event_id = ?',
          whereArgs: [e.googleEventId],
        );
      }
      batch.insert(
        _table,
        e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> clearGoogleEntries() async {
    await db.delete(
      _table,
      where: 'source = ?',
      whereArgs: [CalendarEntrySource.google.name],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
