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
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
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
    'Glass month actions stay in selected year and preserve selected day',
    (tester) async {
      await open(tester);
      final state = tester.state<CalendarScreenState>(
        find.byType(CalendarScreen),
      );
      state.selectDate(DateTime(2027, 1, 15));
      await tester.pumpAndSettle();
      final previous = find.byKey(const Key('calendar_previous_month'));
      final next = find.byKey(const Key('calendar_next_month'));
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      var calendar = tester.widget<TableCalendar>(
        find.byWidgetPredicate((w) => w is TableCalendar),
      );
      expect(calendar.focusedDay.month, 2);
      expect(calendar.focusedDay.year, 2027);
      expect(calendar.selectedDayPredicate!(DateTime(2027, 1, 15)), isTrue);
      state.selectDate(DateTime(2027, 12, 15));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      calendar = tester.widget<TableCalendar>(
        find.byWidgetPredicate((w) => w is TableCalendar),
      );
      expect(calendar.focusedDay.month, 11);
      expect(calendar.focusedDay.year, 2027);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Year selector changes bounds and Today resets to the current year',
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
        [2027, 1, 1],
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
      expect(
        calendar.firstDay.year,
        [2026, 2027].contains(DateTime.now().year) ? DateTime.now().year : 2027,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'UI import uses selected whole year and reflects a deleted Google event',
    (tester) async {
      await open(tester);
      await year2027(tester);
      google.events = [
        event('Deleted in Google'),
        event('Keep December', start: '2027-12-31', end: '2028-01-01'),
      ];
      await import(tester);
      expect(google.min, DateTime(2027));
      expect(google.max, DateTime(2028));
      expect(repo.entries, hasLength(2));
      google.events = [
        event('Keep December', start: '2027-12-31', end: '2028-01-01'),
      ];
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
