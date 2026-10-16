import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/settings_group.dart';
import 'package:ekadashi_calendar/screens/widgets/event_reminder_rows.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/notifications/event_reminder_service.dart';
import 'package:ekadashi_calendar/services/notifications/event_reminders.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/premium_fixture.dart';

/// Phase 7 (docs/ROADMAP.md): Settings > Notifications > Festivals and
/// events, as on iOS: the user's reminders, an editor and an event picker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => SearchCatalog.load());

  late EventReminderService service;
  late List<List<PlannedEventReminder>> scheduled;
  late int upgrades;
  late PremiumService premiumService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    scheduled = [];
    upgrades = 0;
    premiumService = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
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
    UpgradeAction? onUpgrade,
    bool realPaywall = false,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(premiumService.dispose);
    if (premium) premiumService.applyOwned({PremiumService.subscriptionId});
    final billing = FixtureBilling(premiumService);
    addTearDown(billing.dispose);
    await service.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageService()),
          ChangeNotifierProvider<PremiumService?>.value(value: premiumService),
          ChangeNotifierProvider<PlayBillingService?>.value(value: billing),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                realPaywall
                    ? EventReminderRows(
                        service: service,
                        enabled: enabled,
                        premium: premium,
                      )
                    : EventReminderRows(
                        service: service,
                        enabled: enabled,
                        premium: premium,
                        onUpgrade: onUpgrade ?? (_) async => upgrades++,
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
    expect(find.text('All custom events'), findsOneWidget);
    expect(
      find.text('On the day, 1 day before, 2 days before · 7:00 AM'),
      findsOneWidget,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('event_reminders'),
      contains('calendar:custom'),
    );
  });

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('notifications_add_event')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event_reminder_choose')));
    await tester.pumpAndSettle();
  }

  Future<Finder> findDeepavali(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('event_reminder_search')),
      'deepa',
    );
    await tester.pumpAndSettle();
    return find.byKey(const Key('event_choice_observance:deepavali'));
  }

  testWidgets('the editor is an iOS sheet without a locked section', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('notifications_add_event')));
    await tester.pumpAndSettle();
    // A sheet over the page, Cancel and Save in its bar.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(SheetBar), findsOneWidget);
    expect(
      find.descendant(of: find.byType(SheetBar), matching: find.text('Cancel')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('event_reminder_upgrade')), findsNothing);
    // The iOS grouped page (systemGroupedBackground) behind the cards.
    final page = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scaffold),
      ),
    );
    expect(page.backgroundColor, const Color(0xFFF2F2F7));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('the picker is a grouped list with a teal search field', (
    tester,
  ) async {
    await pump(tester);
    await openPicker(tester);
    final search = tester.widget<TextField>(
      find.byKey(const Key('event_reminder_search')),
    );
    expect(search.cursorColor, IosColors.teal);
    expect(search.decoration?.border, InputBorder.none);
    final custom = find.byKey(const Key('event_choice_calendar:custom'));
    await tester.scrollUntilVisible(
      custom,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.ancestor(of: custom, matching: find.byType(SettingsCard)),
      findsOneWidget,
    );
    expect(find.byType(SettingsHeader), findsWidgets);
  });

  testWidgets('a locked event opens the paywall and is not chosen', (
    tester,
  ) async {
    await pump(tester);
    await openPicker(tester);
    final deepavali = await findDeepavali(tester);
    expect(
      find.descendant(of: deepavali, matching: find.byIcon(AppIcons.lock)),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('event_choice_calendar:custom')),
      findsNothing,
      reason: 'the search narrows the list',
    );
    await tester.tap(deepavali);
    await tester.pumpAndSettle();
    expect(upgrades, 1);
    // Still free: the picker stays and nothing is chosen.
    expect(deepavali, findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('event_reminder_save')))
          .onPressed,
      isNull,
    );
    expect(service.reminders, isEmpty);
  });

  testWidgets('the paywall says why it opened', (tester) async {
    await pump(tester, realPaywall: true);
    await openPicker(tester);
    await tester.tap(await findDeepavali(tester));
    await tester.pumpAndSettle();
    final paywall = tester.widget<PremiumScreen>(find.byType(PremiumScreen));
    expect(paywall.reasonKey, 'notifications_premium_events');
  });

  testWidgets('a locked event is chosen once Premium becomes active', (
    tester,
  ) async {
    await pump(
      tester,
      onUpgrade: (_) async {
        upgrades++;
        premiumService.applyOwned({PremiumService.subscriptionId});
      },
    );
    await openPicker(tester);
    await tester.tap(await findDeepavali(tester));
    await tester.pumpAndSettle();
    expect(upgrades, 1);
    expect(find.byKey(const Key('event_reminder_search')), findsNothing);
    await tester.tap(find.byKey(const Key('event_reminder_save')));
    await tester.pumpAndSettle();
    expect(
      service.reminders.single.target,
      const EventReminderTarget.observance('deepavali'),
    );
  });

  testWidgets('a locked reminder saved earlier stays and shows its lock', (
    tester,
  ) async {
    await service.upsert(
      EventReminder(target: const EventReminderTarget.observance('deepavali')),
    );
    await pump(tester);
    final row = find.byKey(
      const Key('event_reminder_row_observance:deepavali'),
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byIcon(AppIcons.lock)),
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
      find.descendant(of: row, matching: find.byIcon(AppIcons.lock)),
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
