import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/services/notifications/event_reminder_service.dart';
import 'package:ekadashi_calendar/services/notifications/event_reminders.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 7: the service hands the planned reminders to the platform, and
/// clears them when notifications are off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting();
    await SearchCatalog.load();
  });

  final now = DateTime.parse('2026-10-08T10:00:00+05:30');
  final entry = CalendarEntry(
    id: 'c1',
    title: 'Temple visit',
    startAt: DateTime(2026, 10, 20, 9),
    endAt: DateTime(2026, 10, 20, 10),
    source: CalendarEntrySource.custom,
    updatedAt: now,
  );

  Future<List<PlannedEventReminder>> run({
    required bool enabled,
    required bool premium,
  }) async {
    SharedPreferences.setMockInitialValues({
      'event_reminders': EventReminderSettings(
        reminders: [
          EventReminder(
            target: const EventReminderTarget.observance('amavasya'),
            daysBefore: const [1],
          ),
          EventReminder(
            target: const EventReminderTarget.calendar(
              CalendarEntrySource.custom,
            ),
            daysBefore: const [1],
          ),
        ],
      ).encode(),
    });
    late List<PlannedEventReminder> scheduled;
    final service = EventReminderService(
      scheduler: (planned) async {
        scheduled = planned;
        return planned.length;
      },
    );
    await service.schedule(
      enabled: enabled,
      premium: premium,
      language: 'en',
      city: PanchangCity.newDelhi,
      entries: [entry],
      now: now,
    );
    return scheduled;
  }

  test('notifications off clears every event reminder', () async {
    expect(await run(enabled: false, premium: true), isEmpty);
  });

  test('free users get their entry reminders only', () async {
    final planned = await run(enabled: true, premium: false);
    expect(planned.map((p) => p.title), ['Temple visit']);
  });

  test('Premium adds Panchang reminders at the Panchang location', () async {
    final planned = await run(enabled: true, premium: true);
    expect(planned.map((p) => p.title), contains('Amavasya'));
    expect(planned.map((p) => p.title), contains('Temple visit'));
    expect(
      planned.firstWhere((p) => p.title == 'Amavasya').fireDate,
      DateTime.parse('2026-10-09T07:00:00+05:30'),
    );
  });
}
