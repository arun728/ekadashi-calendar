import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/services/notifications/event_reminders.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Phase 7 (docs/ROADMAP.md): reminders for festivals, Panchang days and
/// calendar entries, each a chosen number of days before at a chosen time.
/// Mirrors ios-native EventReminderTests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SearchCatalog catalog;
  late List<DatedObservance> observances;
  const city = PanchangCity.newDelhi;

  setUpAll(() async {
    await initializeDateFormatting();
    catalog = await SearchCatalog.load();
    observances = PanchangEngine().observanceCalendar(2026, city: city);
  });

  DateTime ist(String local) => DateTime.parse('$local+05:30');

  List<PlannedEventReminder> plan(
    List<EventReminder> reminders, {
    List<CalendarEntry> entries = const [],
    required DateTime now,
    bool premium = true,
    bool enabled = true,
    int limit = 64,
  }) => EventReminderPlanner.plan(
    settings: EventReminderSettings(enabled: enabled, reminders: reminders),
    observances: observances,
    entries: entries,
    observanceCity: city,
    entryZone: city.zone,
    language: 'en',
    premium: premium,
    now: now,
    limit: limit,
    catalog: catalog,
  );

  test('settings round-trip as the iOS JSON, with defaults', () {
    expect(EventReminderSettings.decode(null).reminders, isEmpty);
    final settings = EventReminderSettings(
      reminders: [
        EventReminder(
          target: const EventReminderTarget.observance('amavasya'),
          daysBefore: const [1, 2],
          hour: 7,
          minute: 30,
        ),
        EventReminder(
          target: const EventReminderTarget.calendar(
            CalendarEntrySource.custom,
          ),
          daysBefore: const [0],
          hour: 6,
        ),
      ],
    );
    final json = settings.encode();
    expect(
      json,
      '[{"daysBefore":[1,2],"hour":7,"minute":30,"target":"observance:amavasya"},'
      '{"daysBefore":[0],"hour":6,"minute":0,"target":"calendar:custom"}]',
    );
    expect(EventReminderSettings.decode(json), settings);
  });

  test('Amavasya one day before at 7:30', () {
    final reminder = EventReminder(
      target: const EventReminderTarget.observance('amavasya'),
      daysBefore: const [1],
      hour: 7,
      minute: 30,
    );
    final result = plan([reminder], now: ist('2026-10-08T10:00:00'));
    expect(result.first.fireDate, ist('2026-10-09T07:30:00'));
    expect(result.first.title, 'Amavasya');
    expect(result.first.body, 'Amavasya is tomorrow (Sat, 10 Oct 2026)');
    expect(result, hasLength(3), reason: 'October, November and December');
    expect(
      result.every((r) => r.url.startsWith('ekadashi://panchang?date=')),
      isTrue,
    );
    expect(result.first.url, 'ekadashi://panchang?date=2026-10-10');
  });

  test('several lead times and the day itself', () {
    final reminder = EventReminder(
      target: const EventReminderTarget.observance('deepavali'),
      daysBefore: const [0, 2],
      hour: 6,
    );
    final result = plan([reminder], now: ist('2026-10-08T10:00:00'));
    expect(result.map((r) => r.fireDate), [
      ist('2026-11-06T06:00:00'),
      ist('2026-11-08T06:00:00'),
    ]);
    expect(result.map((r) => r.body), [
      'Deepavali (Lakshmi Puja) is in 2 days (Sun, 8 Nov 2026)',
      'Deepavali (Lakshmi Puja) is today (Sun, 8 Nov 2026)',
    ]);
    expect(result.map((r) => r.id).toSet(), hasLength(2));
  });

  test('calendar entries by source are free', () {
    final start = ist('2026-10-20T09:00:00');
    CalendarEntry entry(String id, String title, CalendarEntrySource source) =>
        CalendarEntry(
          id: id,
          title: title,
          startAt: start,
          endAt: start.add(const Duration(hours: 1)),
          source: source,
          updatedAt: start,
        );
    final custom = EventReminder(
      target: const EventReminderTarget.calendar(CalendarEntrySource.custom),
      daysBefore: const [1],
      hour: 20,
    );
    final result = plan(
      [custom],
      entries: [
        entry('c1', 'Temple visit', CalendarEntrySource.custom),
        entry('g1', 'Satsang', CalendarEntrySource.google),
      ],
      now: ist('2026-10-08T10:00:00'),
      premium: false,
    );
    expect(result.map((r) => r.title), ['Temple visit']);
    expect(result.first.fireDate, ist('2026-10-19T20:00:00'));
    expect(result.first.url, 'ekadashi://calendar?date=2026-10-20');
  });

  test('Panchang reminders need Premium and the master switch', () {
    final reminder = EventReminder(
      target: const EventReminderTarget.observance('purnima'),
      daysBefore: const [1],
    );
    final now = ist('2026-10-08T10:00:00');
    expect(plan([reminder], now: now, premium: false), isEmpty);
    expect(plan([reminder], now: now, enabled: false), isEmpty);
    expect(plan([reminder], now: now), isNotEmpty);
  });

  test('past times are skipped and the limit keeps the soonest', () {
    final every = [
      for (final o in catalog.observances)
        EventReminder(
          target: EventReminderTarget.observance(o.key),
          daysBefore: const [0, 1, 2],
        ),
    ];
    final now = ist('2026-10-08T10:00:00');
    final result = plan(every, now: now, limit: 20);
    expect(result, hasLength(20));
    expect(result.every((r) => r.fireDate.isAfter(now)), isTrue);
    final times = result.map((r) => r.fireDate).toList();
    expect(times, [...times]..sort());
  });

  test('choices list festivals, monthly days and calendars', () {
    final choices = EventReminderChoice.all('hi', catalog: catalog);
    expect(
      choices.any(
        (c) =>
            c.target == const EventReminderTarget.observance('deepavali') &&
            c.title == 'दीपावली (लक्ष्मी पूजा)',
      ),
      isTrue,
    );
    expect(
      choices.any(
        (c) =>
            c.target == const EventReminderTarget.observance('amavasya') &&
            c.group == EventReminderGroup.monthly,
      ),
      isTrue,
    );
    expect(
      choices.any(
        (c) =>
            c.target ==
                const EventReminderTarget.calendar(
                  CalendarEntrySource.google,
                ) &&
            c.group == EventReminderGroup.myCalendar,
      ),
      isTrue,
    );
    expect(
      choices
          .where((c) => c.group != EventReminderGroup.myCalendar)
          .every((c) => c.requiresPremium),
      isTrue,
    );
    expect(
      choices
          .where((c) => c.group == EventReminderGroup.myCalendar)
          .any((c) => c.requiresPremium),
      isFalse,
    );
    expect(choices.map((c) => c.id).toSet(), hasLength(choices.length));
    expect(choices.any((c) => c.title.startsWith('event_reminder_')), isFalse);
  });

  test('stored reminders survive bad data and replace by event', () {
    expect(EventReminderSettings.decode('not json').reminders, isEmpty);
    var settings = EventReminderSettings();
    settings = settings.upsert(
      EventReminder(
        target: const EventReminderTarget.observance('holi'),
        daysBefore: const [2, 1, 1, 40],
        hour: 30,
        minute: -5,
      ),
    );
    settings = settings.upsert(
      EventReminder(
        target: const EventReminderTarget.observance('holi'),
        daysBefore: const [0],
      ),
    );
    expect(settings.reminders, hasLength(1));
    expect(settings.reminders.single.daysBefore, [0]);
    expect(
      EventReminder(
        target: const EventReminderTarget.observance('holi'),
        daysBefore: const [2, 1, 1, 40],
        hour: 30,
        minute: -5,
      ),
      EventReminder(
        target: const EventReminderTarget.observance('holi'),
        daysBefore: const [1, 2],
        hour: 23,
      ),
    );
    settings = settings.remove(const EventReminderTarget.observance('holi'));
    expect(settings.reminders, isEmpty);
    expect(EventReminderTarget.parse('calendar:nope'), isNull);
    expect(
      EventReminderTarget.parse('observance:holi'),
      const EventReminderTarget.observance('holi'),
    );
  });
}
