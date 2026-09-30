import '../models/calendar_entry.dart';

/// Maps Google Calendar API event JSON (subset) → CalendarEntry.
class GoogleEventMapper {
  static CalendarEntry? fromApiEvent(Map<String, dynamic> event) {
    final id = event['id'] as String?;
    final summary = event['summary'] as String? ?? '(No title)';
    if (id == null) return null;

    final start = event['start'] as Map<String, dynamic>? ?? {};
    final end = event['end'] as Map<String, dynamic>? ?? {};

    DateTime startAt;
    DateTime endAt;
    bool isAllDay = false;

    if (start['date'] != null) {
      // All-day: "2027-08-09"
      isAllDay = true;
      startAt = DateTime.parse(start['date'] as String);
      endAt = end['date'] != null
          ? DateTime.parse(end['date'] as String)
              .subtract(const Duration(days: 1))
          : startAt;
    } else if (start['dateTime'] != null) {
      startAt = DateTime.parse(start['dateTime'] as String).toLocal();
      endAt = end['dateTime'] != null
          ? DateTime.parse(end['dateTime'] as String).toLocal()
          : startAt.add(const Duration(hours: 1));
    } else {
      return null;
    }

    return CalendarEntry(
      id: 'google_$id',
      title: summary,
      notes: event['description'] as String?,
      startAt: startAt,
      endAt: endAt,
      isAllDay: isAllDay,
      source: CalendarEntrySource.google,
      googleEventId: id,
      calendarName: event['calendarName'] as String?,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
