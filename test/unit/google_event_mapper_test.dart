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

  test('an event ending before it starts is still rejected', () {
    expect(
      () => GoogleEventMapper.fromApiEvent(
        _event('2026-10-05T11:00:00+05:30', '2026-10-05T10:00:00+05:30'),
      ),
      throwsFormatException,
    );
  });
}
