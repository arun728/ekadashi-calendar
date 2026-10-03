import 'dart:convert';
import '../models/calendar_entry.dart';

/// Google end dates are exclusive. Timed instants stay in UTC in storage;
/// display conversion happens when the day is viewed, preserving DST semantics.
class GoogleEventMapper {
  static CalendarEntry? fromApiEvent(Map<String, dynamic> event) {
    if (event['status'] == 'cancelled') return null;
    final id = event['id'] as String?;
    final account = event['accountId'] as String?;
    final calendar = event['calendarId'] as String?;
    if (id == null || account == null || calendar == null) {
      throw const FormatException('Google event has no scoped identity');
    }
    final start = event['start'] as Map<String, dynamic>? ?? {};
    final end = event['end'] as Map<String, dynamic>? ?? {};
    final allDay = start['date'] != null;
    final startAt = DateTime.parse(
      (allDay ? start['date'] : start['dateTime']) as String,
    );
    final endAt = DateTime.parse(
      (allDay ? end['date'] : end['dateTime']) as String,
    );
    if (!endAt.isAfter(startAt)) {
      throw const FormatException('Invalid Google event interval');
    }
    final identity = base64Url.encode(
      utf8.encode(jsonEncode([account, calendar, id])),
    );
    return CalendarEntry(
      id: 'google_$identity',
      title: event['summary'] as String? ?? '',
      notes: event['description'] as String?,
      startAt: allDay ? startAt : startAt.toUtc(),
      endAt: allDay ? endAt : endAt.toUtc(),
      isAllDay: allDay,
      source: CalendarEntrySource.google,
      googleEventId: id,
      accountId: account,
      calendarId: calendar,
      calendarName: event['calendarName'] as String?,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
