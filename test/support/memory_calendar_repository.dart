import 'package:ekadashi_calendar/data/calendar_entry_repository.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';

class MemoryCalendarRepository implements CalendarEntryRepository {
  final Map<String, CalendarEntry> entries = {};
  bool fail = false;
  @override
  Future<void> init() async {
    if (fail) throw StateError('Storage failed');
  }

  @override
  Future<void> close() async {}
  @override
  Future<List<CalendarEntry>> getAll() async => entries.values.toList();
  @override
  Future<List<CalendarEntry>> getForDay(DateTime day) async =>
      entries.values.where((e) => e.occursOn(day)).toList();
  @override
  Future<List<CalendarEntry>> getBySource(CalendarEntrySource source) async =>
      entries.values.where((e) => e.source == source).toList();
  @override
  Future<void> upsert(CalendarEntry entry) async {
    entries[entry.id] = entry;
  }

  @override
  Future<void> delete(String id) async {
    entries.remove(id);
  }

  @override
  Future<void> deleteByGoogleEventId(String id) async {
    entries.removeWhere((_, e) => e.googleEventId == id);
  }

  @override
  Future<void> upsertGoogleBatch(List<CalendarEntry> records) async {
    for (final e in records) {
      entries[e.id] = e;
    }
  }

  @override
  Future<void> clearGoogleEntries({String? accountId}) async {
    entries.removeWhere(
      (_, e) =>
          e.source == CalendarEntrySource.google &&
          (accountId == null || accountId == e.accountId),
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
    this.entries.removeWhere(
      (_, e) =>
          e.source == CalendarEntrySource.google &&
          e.accountId == accountId &&
          calendarIds.contains(e.calendarId) &&
          e.startAt.isBefore(timeMax) &&
          e.endAt.isAfter(timeMin),
    );
    for (final entry in entries) {
      this.entries[entry.id] = entry;
    }
  }
}
