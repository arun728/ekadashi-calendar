import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/google_event_mapper.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';

void main() {
  test('maps timed Google event', () {
    final entry = GoogleEventMapper.fromApiEvent({
      'id': 'abc',
      'summary': 'Team sync',
      'description': 'Weekly',
      'start': {'dateTime': '2027-08-09T10:00:00+05:30'},
      'end': {'dateTime': '2027-08-09T11:00:00+05:30'},
    });
    expect(entry, isNotNull);
    expect(entry!.source, CalendarEntrySource.google);
    expect(entry.title, 'Team sync');
    expect(entry.isAllDay, isFalse);
    expect(entry.googleEventId, 'abc');
    expect(entry.id, 'google_abc');
  });

  test('maps all-day Google event', () {
    final entry = GoogleEventMapper.fromApiEvent({
      'id': 'day1',
      'summary': 'Holiday',
      'start': {'date': '2027-08-15'},
      'end': {'date': '2027-08-16'},
    });
    expect(entry, isNotNull);
    expect(entry!.isAllDay, isTrue);
    expect(entry.startAt.year, 2027);
    expect(entry.startAt.month, 8);
    expect(entry.startAt.day, 15);
  });

  test('returns null without id', () {
    expect(
      GoogleEventMapper.fromApiEvent({'summary': 'x'}),
      isNull,
    );
  });
}
