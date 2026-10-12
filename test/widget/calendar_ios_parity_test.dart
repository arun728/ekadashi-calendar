import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/screens/widgets/google_calendar_picker_sheet.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/google_calendar_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/widgets/glass_tube.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../support/app_harness.dart';
import '../support/fake_free_sync_registry.dart';
import '../support/memory_calendar_repository.dart';
import '../support/premium_fixture.dart';
import 'multi_year_calendar_test.dart' show UiGoogle;

/// The Calendar tab matches the iOS CalendarView, EntryEditorView,
/// GoogleCalendarPickerView and the shared month picker sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = EkadashiService();
  late MemoryCalendarRepository repo;
  late LanguageService language;
  setUpAll(() async {
    await data.initializeData();
    await initializeDateFormatting();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = MemoryCalendarRepository();
    language = LanguageService();
  });

  List<EkadashiDate> ekadashis() =>
      data.getEkadashis(timezone: 'IST', languageCode: 'en');

  Future<void> open(WidgetTester tester, {GoogleAuthGateway? google}) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = true,
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
            ekadashiList: ekadashis(),
            repository: repo,
            currentTimezone: 'IST',
            clock: () => DateTime(2026, 10, 5),
            freeSyncRegistry: FakeFreeSyncRegistry(),
            googleService: GoogleCalendarService(
              auth: google ?? UiGoogle(),
              repository: repo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CalendarEntry custom({
    String id = 'c1',
    DateTime? start,
    DateTime? end,
    bool allDay = false,
  }) => CalendarEntry(
    id: id,
    title: 'My entry',
    startAt: start ?? DateTime(2026, 10, 5, 9),
    endAt: end ?? DateTime(2026, 10, 5, 10),
    isAllDay: allDay,
    source: CalendarEntrySource.custom,
    updatedAt: DateTime(2026),
  );

  CalendarScreenState state(WidgetTester tester) =>
      tester.state<CalendarScreenState>(find.byType(CalendarScreen));

  Future<void> select(WidgetTester tester, DateTime day) async {
    state(tester).selectDate(day);
    await tester.pumpAndSettle();
  }

  GlassChip chip(WidgetTester tester, String name) =>
      tester.widget<GlassChip>(find.byKey(Key('calendar_filter_$name')));

  final grid = find.byWidgetPredicate((w) => w is TableCalendar);
  Finder inGrid(String text) =>
      find.descendant(of: grid, matching: find.text(text));

  group('Filters', () {
    testWidgets('open on All, as separate glass chips with their colours', (
      tester,
    ) async {
      await open(tester);
      expect(chip(tester, 'all').selected, isTrue);
      expect(chip(tester, 'ekadashi').selected, isFalse);
      expect(chip(tester, 'all').color, IosColors.teal);
      expect(chip(tester, 'ekadashi').color, IosColors.teal);
      expect(chip(tester, 'google').color, IosColors.googleBlue);
      expect(chip(tester, 'custom').color, IosColors.customPurple);
      // No shared tube and no Material checkmark chips.
      expect(
        find.descendant(
          of: find.byType(CalendarScreen),
          matching: find.byType(GlassTube),
        ),
        findsNothing,
      );
      expect(find.byType(FilterChip), findsNothing);
      await tester.tap(find.byKey(const Key('calendar_filter_custom')));
      await tester.pumpAndSettle();
      expect(chip(tester, 'custom').selected, isTrue);
      expect(chip(tester, 'all').selected, isFalse);
    });
  });

  group('Toolbar', () {
    testWidgets('Today, Add and the Google menu, not an in-page action row', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const Key('calendar_actions_tube')), findsNothing);
      final bar = find.byType(AppBar);
      for (final key in [
        'calendar_today',
        'add_calendar_entry',
        'calendar_google_menu',
      ]) {
        expect(
          find.descendant(of: bar, matching: find.byKey(Key(key))),
          findsOneWidget,
          reason: key,
        );
      }
      // Today is a teal bar button, disabled while today is shown.
      final today = tester.widget<BarTextButton>(
        find.byKey(const Key('calendar_today')),
      );
      expect(today.onPressed, isNull);
      // Import and Disconnect live in the Google menu; Disconnect is red.
      expect(find.byKey(const Key('import_google_year')), findsNothing);
      await tester.tap(find.byKey(const Key('calendar_google_menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import_google_year')), findsOneWidget);
      expect(find.text('Import Google Calendar'), findsOneWidget);
      final disconnect = tester.widget<Text>(
        find.text('Disconnect Google Calendar'),
      );
      expect(disconnect.style?.color, IosColors.red(tester.element(bar)));
    });

    testWidgets('the shell shows them in its top bar', (tester) async {
      final harness = AppHarness();
      await harness.install();
      addTearDown(harness.uninstall);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('glass_tab_1')));
      await tester.pumpAndSettle();
      final calendar = find.byType(CalendarScreen);
      for (final key in [
        'calendar_today',
        'add_calendar_entry',
        'calendar_google_menu',
      ]) {
        final item = find.byKey(Key(key));
        expect(item, findsOneWidget, reason: key);
        expect(
          find.descendant(of: calendar, matching: item),
          findsNothing,
          reason: '$key belongs to the shared top bar',
        );
        expect(
          tester.getRect(item).top,
          lessThan(
            tester.getRect(find.byKey(const Key('calendar_filters_tube'))).top,
          ),
        );
      }
      // Other tabs do not show the Calendar items.
      await tester.tap(find.byKey(const Key('glass_tab_0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add_calendar_entry')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Month header and grid', () {
    testWidgets('title 20 bold with a chevron, both arrows at the right', (
      tester,
    ) async {
      await open(tester);
      final header = find.byKey(const Key('calendar_month_tube'));
      expect(
        find.descendant(of: header, matching: find.byType(GlassTube)),
        findsNothing,
      );
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('calendar_year_selector')),
          matching: find.text('Mon, 5 Oct 2026'),
        ),
      );
      expect(title.style?.fontSize, IosText.title3);
      expect(title.style?.fontWeight, FontWeight.w700);
      final selector = tester.getRect(
        find.byKey(const Key('calendar_year_selector')),
      );
      final previous = tester.getRect(
        find.byKey(const Key('calendar_previous_month')),
      );
      final next = tester.getRect(find.byKey(const Key('calendar_next_month')));
      expect(selector.left, lessThan(40));
      expect(previous.left, greaterThan(selector.right));
      expect(next.left, greaterThanOrEqualTo(previous.right - 1));
      expect(next.left - previous.right, lessThan(8));
      expect(
        find.descendant(
          of: find.byKey(const Key('calendar_year_selector')),
          matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('single-letter weekdays, no adjacent-month days', (
      tester,
    ) async {
      await open(tester);
      for (final letter in ['M', 'W', 'F']) {
        expect(inGrid(letter), findsOneWidget, reason: letter);
      }
      expect(inGrid('S'), findsNWidgets(2));
      expect(inGrid('Mon'), findsNothing);
      // October 2026 starts on a Thursday: September 27-30 are not shown.
      expect(inGrid('27'), findsOneWidget);
      expect(inGrid('30'), findsOneWidget);
      // ...and November 1 after October 31 is not shown either.
      expect(inGrid('1'), findsOneWidget);
    });

    testWidgets('selected bold white on teal, today half teal, weekend same', (
      tester,
    ) async {
      await open(tester);
      await select(tester, DateTime(2026, 10, 20));
      final context = tester.element(grid);
      final selected = tester.widget<Text>(inGrid('20'));
      expect(selected.style?.fontWeight, FontWeight.w700);
      expect(selected.style?.color, Colors.white);
      expect(selected.style?.fontSize, IosText.callout);
      BoxDecoration circle(String day) =>
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: inGrid(day),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(circle('20').color, IosColors.teal);
      final selectedBox = tester.getSize(
        find.ancestor(of: inGrid('20'), matching: find.byType(Container)).first,
      );
      expect(selectedBox.width, 38);
      // Today (the clock's 5 October) is half teal with primary text.
      expect(circle('5').color, IosColors.teal.withValues(alpha: .5));
      final today = tester.widget<Text>(inGrid('5'));
      expect(today.style?.color, IosColors.primary(context));
      expect(today.style?.fontWeight, isNot(FontWeight.w700));
      // A Sunday looks like a weekday.
      expect(
        tester.widget<Text>(inGrid('4')).style?.color,
        tester.widget<Text>(inGrid('6')).style?.color,
      );
    });

    testWidgets('No Ekadashi sits below the grid, left aligned', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('calendar_filter_ekadashi')));
      await tester.pumpAndSettle();
      await select(tester, DateTime(2026, 10, 1));
      final empty = find.byKey(const Key('calendar_no_ekadashi'));
      expect(empty, findsOneWidget);
      expect(
        tester.getRect(empty).top,
        greaterThan(tester.getRect(grid).bottom),
      );
      expect(tester.getRect(empty).left, closeTo(16, 1));
      expect(tester.widget<Text>(empty).style?.fontSize, IosText.subheadline);
    });

    testWidgets('the month picker is a wheel sheet with Cancel and Done', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('calendar_year_selector')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      expect(find.byKey(const Key('month_picker_cancel')), findsOneWidget);
      // Full month names, the data years only.
      expect(find.text('October'), findsOneWidget);
      expect(find.byKey(const Key('month_picker_year_2025')), findsNothing);
      // Cancel leaves the month as it was.
      await tester.tap(find.byKey(const Key('month_picker_year_2027')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month_picker_cancel')));
      await tester.pumpAndSettle();
      expect(state(tester).selectedYear, 2026);
      // Done applies the wheels.
      await tester.tap(find.byKey(const Key('calendar_year_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month_picker_year_2027')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('panchang_month_9')));
      await tester.pumpAndSettle();
      expect(state(tester).selectedYear, 2026);
      await tester.tap(find.byKey(const Key('month_picker_done')));
      await tester.pumpAndSettle();
      expect(state(tester).selectedYear, 2027);
      final focused = tester.widget<TableCalendar>(grid).focusedDay;
      expect([focused.year, focused.month, focused.day], [2027, 9, 1]);
    });
  });

  group('Day card', () {
    testWidgets('glass card with fasting times; no zone, no Not Recorded', (
      tester,
    ) async {
      await open(tester);
      final ekadashi = ekadashis().firstWhere(
        (e) => e.date.year == 2026 && e.date.month == 10,
      );
      await select(tester, ekadashi.date);
      final card = find.byKey(const Key('calendar_ekadashi_card'));
      expect(tester.widget(card), isA<GlassPanel>());
      expect((tester.widget(card) as GlassPanel).radius, 18);
      Finder inCard(Finder finder) =>
          find.descendant(of: card, matching: finder);
      final name = tester.widget<Text>(inCard(find.text(ekadashi.name)));
      expect(name.style?.fontSize, IosText.headline);
      expect(name.style?.color, IosColors.teal);
      expect(inCard(find.textContaining('Start Fasting: ')), findsOneWidget);
      expect(inCard(find.textContaining('Break Fasting: ')), findsOneWidget);
      expect(inCard(find.text('IST')), findsNothing);
      expect(inCard(find.text('Not Recorded')), findsNothing);
      expect(inCard(find.byType(StatusPill)), findsNothing);
      await tester.tap(find.byKey(const Key('calendar_view_details')));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsScreen), findsOneWidget);
    });
  });

  group('Entries', () {
    testWidgets('rows are glass cards with a long-press menu', (tester) async {
      repo.entries['c1'] = custom();
      await open(tester);
      final row = find.byKey(const Key('calendar_entry_c1'));
      expect(tester.widget(row), isA<GlassPanel>());
      expect((tester.widget(row) as GlassPanel).radius, 14);
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      final title = tester.widget<Text>(find.text('My entry'));
      expect(title.style?.fontSize, IosText.subheadline);
      expect(title.style?.color, IosColors.customPurple);
      await tester.longPress(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendar_entry_edit')), findsOneWidget);
      expect(find.text('Delete Record'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar_entry_delete')));
      await tester.pumpAndSettle();
      expect(repo.entries, isEmpty);
      expect(find.text('My entry'), findsNothing);
      // The empty state is grey and left aligned.
      final empty = find.text('No entries for this day');
      expect(tester.getRect(empty).left, lessThan(60));
    });

    testWidgets('saving keeps the current filter', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('calendar_filter_google')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_calendar_entry')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('entry_title')), 'Kept');
      await tester.tap(find.byKey(const Key('save_entry')));
      await tester.pumpAndSettle();
      expect(repo.entries.values.single.title, 'Kept');
      expect(chip(tester, 'google').selected, isTrue);
      expect(chip(tester, 'custom').selected, isFalse);
    });

    testWidgets('messages are iOS toasts, not snack bars', (tester) async {
      await open(tester, google: _FailingSignIn());
      await tester.tap(find.byKey(const Key('calendar_google_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import_google_year')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app_toast')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('Entry editor', () {
    Future<void> openEditor(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('add_calendar_entry')));
      await tester.pumpAndSettle();
    }

    testWidgets('an iOS sheet: Cancel, title, Save and a placeholder field', (
      tester,
    ) async {
      await open(tester);
      await openEditor(tester);
      expect(find.byType(SheetBar), findsOneWidget);
      expect(find.byKey(const Key('entry_cancel')), findsOneWidget);
      expect(find.byKey(const Key('save_entry')), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      final field = tester.widget<TextField>(
        find.byKey(const Key('entry_title')),
      );
      expect(field.decoration?.hintText, 'Title');
      expect(field.decoration?.labelText, isNull);
      expect(field.autofocus, isFalse);
      final notes = tester.widget<TextField>(
        find.byKey(const Key('entry_notes')),
      );
      expect(notes.minLines, 2);
      expect(notes.maxLines, 5);
      final allDay = tester.widget<Switch>(
        find.descendant(
          of: find.byKey(const Key('entry_all_day')),
          matching: find.byType(Switch),
        ),
      );
      expect(allDay.activeTrackColor, IosColors.teal);
      // Dates and times; all-day keeps the dates and hides the times.
      for (final key in [
        'entry_start_date',
        'entry_start_time',
        'entry_end_date',
        'entry_end_time',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      await tester.tap(find.byKey(const Key('entry_all_day')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('entry_start_date')), findsOneWidget);
      expect(find.byKey(const Key('entry_end_date')), findsOneWidget);
      expect(find.byKey(const Key('entry_start_time')), findsNothing);
      await tester.tap(find.byKey(const Key('entry_cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(SheetBar), findsNothing);
      expect(repo.entries, isEmpty);
    });

    testWidgets('a timed entry can run over several days', (tester) async {
      await open(tester);
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('entry_title')), 'Retreat');
      await tester.tap(find.byKey(const Key('entry_end_date')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('7'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_entry')));
      await tester.pumpAndSettle();
      final entry = repo.entries.values.single;
      expect(entry.startAt, DateTime(2026, 10, 5, 9));
      expect(entry.endAt, DateTime(2026, 10, 7, 10));
      expect(entry.occursOn(DateTime(2026, 10, 6)), isTrue);
      expect(entry.isAllDay, isFalse);
    });

    testWidgets('an all-day entry over several days keeps the stored format', (
      tester,
    ) async {
      await open(tester);
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('entry_title')), 'Trip');
      await tester.tap(find.byKey(const Key('entry_all_day')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entry_end_date')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('8'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_entry')));
      await tester.pumpAndSettle();
      final entry = repo.entries.values.single;
      // Local midnights with an exclusive end, as before.
      expect(entry.startAt, DateTime(2026, 10, 5));
      expect(entry.endAt, DateTime(2026, 10, 9));
      expect(entry.isAllDay, isTrue);
      expect(entry.occursOn(DateTime(2026, 10, 8)), isTrue);
      expect(entry.occursOn(DateTime(2026, 10, 9)), isFalse);
    });

    testWidgets('editing shows the stored dates; end may equal start', (
      tester,
    ) async {
      repo.entries['c1'] = custom(
        start: DateTime(2026, 10, 5, 9),
        end: DateTime(2026, 10, 5, 9),
      );
      await open(tester);
      await tester.tap(find.text('My entry'));
      await tester.pumpAndSettle();
      expect(find.text('Edit entry'), findsOneWidget);
      await tester.tap(find.byKey(const Key('save_entry')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a title and an end time after the start time.'),
        findsNothing,
      );
      expect(find.byType(SheetBar), findsNothing);
      expect(repo.entries['c1']!.endAt, DateTime(2026, 10, 5, 9));
    });

    testWidgets('an all-day entry opens on its last day, not the day after', (
      tester,
    ) async {
      repo.entries['c1'] = custom(
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 8),
        allDay: true,
      );
      await open(tester);
      await tester.tap(find.text('My entry'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('entry_end_date')),
          matching: find.text('7 Oct 2026'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('save_entry')));
      await tester.pumpAndSettle();
      expect(repo.entries['c1']!.endAt, DateTime(2026, 10, 8));
    });

    testWidgets('a save error keeps the sheet open', (tester) async {
      await open(tester);
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('entry_title')), 'Lost?');
      repo.failWrites = true;
      await tester.tap(find.byKey(const Key('save_entry')));
      await tester.pumpAndSettle();
      expect(find.byType(SheetBar), findsOneWidget);
      expect(find.byKey(const Key('app_toast')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('Google picker', () {
    Future<List<String>?> Function() pump(
      WidgetTester tester,
      List<GoogleCalendarInfo> calendars,
      List<String> saved,
    ) {
      List<String>? result;
      var done = false;
      return () async {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: language,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('Open'),
                    onPressed: () async {
                      result = await showGoogleCalendarPickerSheet(
                        context: context,
                        calendars: calendars,
                        initiallySelected: saved,
                        accountEmail: 'me@example.test',
                      );
                      done = true;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        return done ? result : null;
      };
    }

    bool on(WidgetTester tester, String id) =>
        tester.widget<Switch>(find.byKey(Key('google_calendar_$id'))).value;

    testWidgets('switches on the right, primary preselected, Cancel', (
      tester,
    ) async {
      await pump(tester, const [
        GoogleCalendarInfo(id: 'work', summary: 'Work'),
        GoogleCalendarInfo(id: 'me', summary: 'Personal', primary: true),
      ], const [])();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(SheetBar), findsOneWidget);
      expect(on(tester, 'me'), isTrue);
      expect(on(tester, 'work'), isFalse);
      final toggle = tester.widget<Switch>(
        find.byKey(const Key('google_calendar_me')),
      );
      expect(toggle.activeTrackColor, IosColors.googleBlue);
      expect(
        tester.getCenter(find.byKey(const Key('google_calendar_me'))).dx,
        greaterThan(tester.getCenter(find.text('Personal')).dx),
      );
      final import = tester.widget<FilledButton>(
        find.byKey(const Key('import_selected')),
      );
      expect(import.onPressed, isNotNull);
      expect(import.style?.backgroundColor?.resolve({}), IosColors.teal);
      await tester.tap(find.byKey(const Key('google_picker_cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(SheetBar), findsNothing);
    });

    testWidgets('without a primary calendar nothing is preselected', (
      tester,
    ) async {
      await pump(tester, const [
        GoogleCalendarInfo(id: 'work', summary: 'Work'),
      ], const [])();
      expect(on(tester, 'work'), isFalse);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('import_selected')))
            .onPressed,
        isNull,
      );
    });
  });
}

class _FailingSignIn extends UiGoogle {
  @override
  Future<bool> isSignedIn() async => false;
  @override
  Future<bool> signIn() async => throw StateError('No Play services');
}
