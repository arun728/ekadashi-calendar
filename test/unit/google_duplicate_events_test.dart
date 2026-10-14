import 'package:ekadashi_calendar/models/calendar_day_merge.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/services/google_event_mapper.dart';
import 'package:ekadashi_calendar/services/search/search_corpus.dart';
import 'package:flutter_test/flutter_test.dart';

/// The same Google event can arrive twice: from two picked calendars (a
/// holiday calendar and another calendar holding a copy) or listed twice in
/// one calendar. Each keeps its own identity for reconciling deletions, but
/// the app shows, searches and reminds it once (CalendarEntry
/// .withoutDuplicateGoogle on iOS).
void main() {
  CalendarEntry google(
    String calendar,
    String id, {
    String title = 'Dussehra',
  }) => GoogleEventMapper.fromApiEvent({
    'id': id,
    'accountId': 'a',
    'calendarId': calendar,
    'summary': title,
    'description': 'Public holiday',
    'start': {'date': '2026-10-20'},
    'end': {'date': '2026-10-21'},
  })!;

  final copies = [
    google('en.indian#holiday', 'e1'),
    google('primary', 'e2'),
    google('en.indian#holiday', 'e3'),
  ];

  test('identical Google events are kept once, the first one', () {
    final unique = CalendarEntry.withoutDuplicateGoogle([
      ...copies,
      google('primary', 'e4', title: 'Other event'),
    ]);
    expect(unique.map((e) => e.title), ['Dussehra', 'Other event']);
    expect(unique.first.id, copies.first.id);
  });

  test('custom entries with the same title and time are never merged', () {
    CalendarEntry custom(String id) => CalendarEntry(
      id: id,
      title: 'Dussehra',
      startAt: DateTime(2026, 10, 20),
      endAt: DateTime(2026, 10, 21),
      isAllDay: true,
      source: CalendarEntrySource.custom,
      updatedAt: DateTime(2026),
    );
    final list = [custom('c1'), custom('c2'), ...copies];
    expect(CalendarEntry.withoutDuplicateGoogle(list), hasLength(3));
  });

  test('the day list shows the event once', () {
    final items = CalendarDayMerge.merge(
      day: DateTime(2026, 10, 20),
      ekadashis: const [],
      entries: copies,
      filter: CalendarFilter.all,
    );
    expect(items.map((i) => i.title), ['Dussehra']);
  });

  test('search finds the event once', () {
    final items = SearchCorpus.entryItems(copies);
    expect(items, hasLength(1));
  });
}
