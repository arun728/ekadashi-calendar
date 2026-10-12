import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/screens/widgets/event_reminder_rows.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/notifications/event_reminder_service.dart';
import 'package:ekadashi_calendar/services/notifications/event_reminders.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 7 (docs/ROADMAP.md): Settings > Notifications > Festivals and
/// events, as on iOS: the user's reminders, an editor and an event picker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => SearchCatalog.load());

  late EventReminderService service;
  late List<List<PlannedEventReminder>> scheduled;
  late int upgrades;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scheduled = [];
    upgrades = 0;
    service = EventReminderService(
      scheduler: (planned) async {
        scheduled.add(planned);
        return planned.length;
      },
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    bool premium = false,
    bool enabled = true,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await service.load();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageService(),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                EventReminderRows(
                  service: service,
                  enabled: enabled,
                  premium: premium,
                  onUpgrade: (_) async => upgrades++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('adds a free reminder for my own entries', (tester) async {
    await pump(tester);
    expect(find.text('No reminders yet'), findsOneWidget);
    expect(find.byKey(const Key('notifications_add_event')), findsOneWidget);

    await tester.tap(find.byKey(const Key('notifications_add_event')));
    await tester.pumpAndSettle();
    expect(find.text('Add a reminder'), findsWidgets);
    // Save waits for an event.
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('event_reminder_save')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('event_reminder_choose')));
    await tester.pumpAndSettle();
    final custom = find.byKey(const Key('event_choice_calendar:custom'));
    await tester.scrollUntilVisible(
      custom,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(custom);
    await tester.pumpAndSettle();

    // 1 and 2 days before at 7:00 by default.
    for (final lead in EventReminder.leadDays) {
      final selected = tester
          .widget<ListTile>(find.byKey(Key('event_reminder_lead_$lead')))
          .selected;
      expect(selected, EventReminder.defaultLeadDays.contains(lead));
    }
    await tester.tap(find.byKey(const Key('event_reminder_lead_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event_reminder_save')));
    await tester.pumpAndSettle();

    expect(service.reminders, [
      EventReminder(
        target: const EventReminderTarget.calendar(CalendarEntrySource.custom),
        daysBefore: const [0, 1, 2],
      ),
    ]);
    expect(
      find.byKey(const Key('event_reminder_row_calendar:custom')),
      findsOneWidget,
    );
    expect(find.text('All my entries'), findsOneWidget);
    expect(
      find.text('On the day, 1 day before, 2 days before · 7:00 AM'),
      findsOneWidget,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('event_reminders'),
      contains('calendar:custom'),
    );
  });

  testWidgets('festival reminders are Premium, kept and marked locked', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('notifications_add_event')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event_reminder_choose')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('event_reminder_search')),
      'deepa',
    );
    await tester.pumpAndSettle();
    final deepavali = find.byKey(
      const Key('event_choice_observance:deepavali'),
    );
    expect(
      find.descendant(of: deepavali, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('event_choice_calendar:custom')),
      findsNothing,
      reason: 'the search narrows the list',
    );
    await tester.tap(deepavali);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('event_reminder_upgrade')));
    await tester.pumpAndSettle();
    expect(upgrades, 1);

    await tester.tap(find.byKey(const Key('event_reminder_save')));
    await tester.pumpAndSettle();
    final row = find.byKey(
      const Key('event_reminder_row_observance:deepavali'),
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );
  });

  testWidgets('a reminder is edited and deleted from its editor', (
    tester,
  ) async {
    await service.upsert(
      EventReminder(
        target: const EventReminderTarget.observance('amavasya'),
        daysBefore: const [1],
        hour: 6,
        minute: 30,
      ),
    );
    await pump(tester, premium: true);
    final row = find.byKey(const Key('event_reminder_row_observance:amavasya'));
    expect(
      find.descendant(of: row, matching: find.text('Amavasya')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Edit reminder'), findsWidgets);
    await tester.tap(find.byKey(const Key('event_reminder_delete')));
    await tester.pumpAndSettle();
    expect(service.reminders, isEmpty);
    expect(find.text('No reminders yet'), findsOneWidget);
    expect(row, findsNothing);
  });

  testWidgets('everything is disabled while notifications are off', (
    tester,
  ) async {
    await pump(tester, enabled: false);
    await tester.tap(find.byKey(const Key('notifications_add_event')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('event_reminder_choose')), findsNothing);
  });
}
