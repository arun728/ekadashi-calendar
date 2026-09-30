import '../models/calendar_entry.dart';

abstract class CalendarEntryRepository {
  Future<void> init();
  Future<List<CalendarEntry>> getAll();
  Future<List<CalendarEntry>> getForDay(DateTime day);
  Future<List<CalendarEntry>> getBySource(CalendarEntrySource source);
  Future<void> upsert(CalendarEntry entry);
  Future<void> delete(String id);
  Future<void> deleteByGoogleEventId(String googleEventId);
  Future<void> upsertGoogleBatch(List<CalendarEntry> entries);
  Future<void> clearGoogleEntries();
}
