import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';
import '../support/premium_fixture.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/services/google_calendar_service.dart';
import '../support/memory_calendar_repository.dart';
import '../unit/google_reconciliation_test.dart' show FakeGoogle, event;

class UiGoogle extends FakeGoogle {
  @override
  Future<List<GoogleCalendarInfo>> listCalendars() async => [
    const GoogleCalendarInfo(
      id: 'primary',
      summary: 'My calendar',
      primary: true,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = EkadashiService();
  late MemoryCalendarRepository repo;
  late UiGoogle google;
  late LanguageService language;
  setUpAll(() async {
    await data.initializeData();
    await initializeDateFormatting();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = MemoryCalendarRepository();
    google = UiGoogle();
    language = LanguageService();
  });
  Future<void> open(
    WidgetTester tester, {
    bool paid = true,
    DateTime? now,
    DateTime? purchasedAt,
  }) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()
        ..premium = paid
        ..purchasedAt = purchasedAt,
    );
    await premium.refresh();
    addTearDown(premium.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: premium),
          ChangeNotifierProvider<PlayBillingService>(
            create: (_) => FixtureBilling(premium),
          ),
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider(create: (_) => VratTrackerService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CalendarScreen(
            ekadashiList: data.getEkadashis(
              timezone: 'IST',
              languageCode: 'en',
            ),
            repository: repo,
            clock: () => now ?? DateTime(2026, 10, 5),
            googleService: GoogleCalendarService(
              auth: google,
              repository: repo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> year2027(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('calendar_year_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027').last);
    await tester.pumpAndSettle();
  }

  Future<void> import(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('import_google_year')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Import selected'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Free calendar opens premium after the free sync and keeps custom entry free',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        CalendarScreen.freeSyncUsedKey: true,
      });
      await open(tester, paid: false);
      await year2027(tester);
      await tester.tap(find.byKey(const Key('import_google_year')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(google.min, isNull);
      await tester.tap(find.byKey(const Key('premium_close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_calendar_entry')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
      expect(find.byType(PremiumScreen), findsNothing);
    },
  );

  TableCalendar<dynamic> calendarOf(WidgetTester tester) =>
      tester.widget<TableCalendar<dynamic>>(
        find.byWidgetPredicate((w) => w is TableCalendar),
      );

  int? selectorYear(WidgetTester tester) => tester
      .widget<DropdownButton<int>>(
        find.byKey(const Key('calendar_year_selector')),
      )
      .value;

  testWidgets(
    'The calendar runs across every data year, with the selector following',
    (tester) async {
      await open(tester);
      final state = tester.state<CalendarScreenState>(
        find.byType(CalendarScreen),
      );
      final previous = find.byKey(const Key('calendar_previous_month'));
      final next = find.byKey(const Key('calendar_next_month'));
      // The range comes from the bundled year packs (2026 and 2027).
      String ymd(DateTime d) => '${d.year}-${d.month}-${d.day}';
      expect(ymd(calendarOf(tester).firstDay), '2026-1-1');
      expect(ymd(calendarOf(tester).lastDay), '2027-12-31');
      state.selectDate(DateTime(2026, 12, 15));
      await tester.pumpAndSettle();
      await tester.ensureVisible(next);
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(calendarOf(tester).focusedDay.year, 2027);
      expect(calendarOf(tester).focusedDay.month, 1);
      expect(selectorYear(tester), 2027);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(calendarOf(tester).focusedDay.year, 2026);
      expect(calendarOf(tester).focusedDay.month, 12);
      expect(selectorYear(tester), 2026);
      state.selectDate(DateTime(2027, 12, 15));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      state.selectDate(DateTime(2026, 1, 15));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Choosing a year opens its January; the current year, today', (
    tester,
  ) async {
    await open(tester);
    await year2027(tester);
    final focused = calendarOf(tester).focusedDay;
    expect([focused.year, focused.month, focused.day], [2027, 1, 1]);
    await tester.tap(find.byKey(const Key('calendar_year_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    expect(calendarOf(tester).focusedDay.month, 10);
    expect(calendarOf(tester).focusedDay.year, 2026);
  });
  testWidgets(
    'Year selector keeps the full range and Today resets to the current year',
    (tester) async {
      await open(tester);
      await year2027(tester);
      var calendar = tester.widget<TableCalendar>(
        find.byWidgetPredicate((w) => w is TableCalendar),
      );
      expect(
        [
          calendar.firstDay.year,
          calendar.firstDay.month,
          calendar.firstDay.day,
        ],
        [2026, 1, 1],
      );
      expect(
        [calendar.lastDay.year, calendar.lastDay.month, calendar.lastDay.day],
        [2027, 12, 31],
      );
      tester
          .state<CalendarScreenState>(find.byType(CalendarScreen))
          .resetToToday();
      await tester.pumpAndSettle();
      calendar = tester.widget<TableCalendar>(
        find.byWidgetPredicate((w) => w is TableCalendar),
      );
      final now = DateTime.now();
      expect(
        calendar.focusedDay.year,
        [2026, 2027].contains(now.year) ? now.year : 2027,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'UI import uses the subscription year and reflects a deleted Google event',
    (tester) async {
      // A January 2027 subscription syncs January to December 2027.
      await open(
        tester,
        now: DateTime(2027, 3, 1),
        purchasedAt: DateTime(2027, 1, 10),
      );
      await year2027(tester);
      tester
          .state<CalendarScreenState>(find.byType(CalendarScreen))
          .selectDate(DateTime(2027, 1, 1));
      await tester.pumpAndSettle();
      google.events = [
        event('Deleted in Google'),
        event('Keep December', start: '2027-12-31', end: '2028-01-01'),
      ];
      await import(tester);
      expect(google.min, DateTime(2027));
      expect(google.max, DateTime(2028));
      expect(repo.entries, hasLength(2));
      final importedEvent = find.text('Deleted in Google');
      await tester.scrollUntilVisible(
        importedEvent,
        220,
        scrollable: find
            .descendant(
              of: find.byType(CalendarScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(importedEvent, findsOneWidget);
      google.events = [
        event('Keep December', start: '2027-12-31', end: '2028-01-01'),
      ];
      final importButton = find.byKey(const Key('import_google_year'));
      final calendarViewport = find.byType(CustomScrollView).first;
      for (
        var attempt = 0;
        attempt < 20 && importButton.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(calendarViewport, const Offset(0, 500));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(importButton, findsOneWidget);
      await tester.ensureVisible(importButton);
      await import(tester);
      expect(repo.entries.values.map((e) => e.title), ['Keep December']);
      expect(find.text('Deleted in Google'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Custom entry validates times, saves, edits and remains separate from Google',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('add_calendar_entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a title and an end time after the start time.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, 'Private reminder');
      await tester.tap(find.text('All day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.entries, hasLength(1));
      expect(find.text('Private reminder'), findsOneWidget);
      final entry = repo.entries.values.single;
      expect(entry.endAt.isAfter(entry.startAt), isTrue);
      expect(
        entry.occursOn(
          DateTime(
            entry.startAt.year,
            entry.startAt.month,
            entry.startAt.day + 1,
          ),
        ),
        isFalse,
      );
      await tester.tap(find.text('Private reminder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Edited reminder');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.entries.values.single.title, 'Edited reminder');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Storage failure is visible and disables CRUD until retry succeeds',
    (tester) async {
      repo.fail = true;
      await open(tester);
      expect(
        find.text('Calendar storage is unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('add_calendar_entry')))
            .onPressed,
        isNull,
      );
      repo.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('add_calendar_entry')))
            .onPressed,
        isNotNull,
      );
    },
  );
}
