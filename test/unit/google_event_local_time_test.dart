import 'package:ekadashi_calendar/models/calendar_day_merge.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/services/google_event_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Google event created for 4:30–5:30 PM IST arrives as an RFC 3339
/// instant. Every time shown to the user must be in the phone's local time,
/// never UTC.
void main() {
  final entry = GoogleEventMapper.fromApiEvent({
    'id': 'e1',
    'accountId': 'a',
    'calendarId': 'c',
    'summary': 'Test event',
    'start': {'dateTime': '2026-10-06T16:30:00+05:30'},
    'end': {'dateTime': '2026-10-06T17:30:00+05:30'},
  })!;

  test('the day list gets local times for a timed Google event', () {
    final items = CalendarDayMerge.merge(
      day: DateTime(2026, 10, 6),
      ekadashis: const [],
      entries: [entry],
      filter: CalendarFilter.google,
    );
    final item = items.single;
    expect(item.startAt!.isUtc, isFalse);
    expect(item.endAt!.isUtc, isFalse);
    expect(
      item.startAt!.isAtSameMomentAs(DateTime.utc(2026, 10, 6, 11, 0)),
      isTrue,
    );
    expect(item.startAt, entry.startAt.toLocal());
  });

  test('the entry exposes local start and end times', () {
    expect(entry.localStart.isUtc, isFalse);
    expect(entry.localEnd, entry.endAt.toLocal());
  });

  test('custom entries (stored in local time) are unchanged', () {
    final custom = CalendarEntry(
      id: 'c1',
      title: 'Custom',
      startAt: DateTime(2026, 10, 6, 16, 30),
      endAt: DateTime(2026, 10, 6, 17, 30),
      source: CalendarEntrySource.custom,
      updatedAt: DateTime(2026),
    );
    expect(custom.localStart, DateTime(2026, 10, 6, 16, 30));
  });
}
