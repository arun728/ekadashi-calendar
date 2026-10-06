import 'package:ekadashi_calendar/services/google_event_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _event(String start, String end) => {
  'id': 'e1',
  'accountId': 'a',
  'calendarId': 'c',
  'summary': 'Reminder',
  'start': {'dateTime': start},
  'end': {'dateTime': end},
};

void main() {
  test('a zero-length Google event (end equals start) is imported', () {
    final entry = GoogleEventMapper.fromApiEvent(
      _event('2026-10-05T10:00:00+05:30', '2026-10-05T10:00:00+05:30'),
    );
    expect(entry, isNotNull);
    expect(entry!.startAt, entry.endAt);
  });

  test('an event ending before it starts becomes an instant at its start', () {
    final entry = GoogleEventMapper.fromApiEvent(
      _event('2026-10-05T11:00:00+05:30', '2026-10-05T10:00:00+05:30'),
    );
    expect(entry!.endAt, entry.startAt);
  });

  test('an all-day event without a later end covers its start day', () {
    for (final end in [null, '2026-10-05', '2026-10-04']) {
      final entry = GoogleEventMapper.fromApiEvent({
        'id': 'e2',
        'accountId': 'a',
        'calendarId': 'c',
        'start': {'date': '2026-10-05'},
        'end': {'date': ?end},
      });
      expect(entry!.isAllDay, isTrue);
      expect(entry.endAt, DateTime(2026, 10, 6), reason: 'end $end');
    }
  });

  test('an event without a start is rejected', () {
    expect(
      () => GoogleEventMapper.fromApiEvent({
        'id': 'e3',
        'accountId': 'a',
        'calendarId': 'c',
        'start': <String, dynamic>{},
        'end': {'date': '2026-10-06'},
      }),
      throwsFormatException,
    );
  });
}
