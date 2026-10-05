import '../test/support/premium_fixture.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:table_calendar/table_calendar.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/services/widget_sync_manager.dart';
import 'package:ekadashi_calendar/services/native_widget_service.dart';
import 'package:ekadashi_calendar/services/search_index_manager.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/services/google_calendar_service.dart';
import 'package:ekadashi_calendar/services/native_settings_service.dart';
import 'package:ekadashi_calendar/services/native_notification_service.dart';
import 'package:ekadashi_calendar/data/sqflite_calendar_entry_repository.dart';
import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import '../test/unit/google_reconciliation_test.dart' show FakeGoogle, event;

class AndroidTestGoogle extends FakeGoogle {
  @override
  Future<List<GoogleCalendarInfo>> listCalendars() async => [
    const GoogleCalendarInfo(
      id: 'primary',
      summary: 'Test calendar',
      primary: true,
    ),
  ];
}

Future<void> frames(WidgetTester tester, {int count = 6}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 60 && !ready(); i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  expect(ready(), isTrue);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Multi-year archive, Telugu, SQLite persistence and whole-year Google deletion',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      await prefs.setBool('is_dark_mode', true);
      const old = VratHistory(
        id: 'migration-fixture',
        ekadashiOccurrenceId: 1,
        ekadashiDate: '2026-01-14',
        ekadashiName: 'Shattila Ekadashi',
        status: ObservanceStatus.observed,
        note: 'Archived private note',
        timezone: 'IST',
        tradition: 'Vaishnava',
        recordedAtUTC: '2026-01-14T12:00:00Z',
        updatedAtUTC: '2026-01-14T12:00:00Z',
      );
      await prefs.setString('vrat_tracker_history', jsonEncode([old.toJson()]));
      await prefs.setBool('vrat_tracker_enabled', true);
      await prefs.setStringList('vrat_tracker_notified_achievements', [
        'first_vrat',
      ]);
      await NativeSettingsService().updateNotificationSettings(
        NotificationPrefs.defaults(),
      );
      await NativeNotificationService().updateSettings(NotificationSettings());
      app.main();
      await tester.pump();
      await until(tester, () => find.byIcon(Icons.home).evaluate().isNotEmpty);
      await until(
        tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      await binding.convertFlutterSurfaceToImage();
      await frames(tester);
      expect(find.byKey(const Key('glass_navigation_bar')), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(Key('glass_tab_$i')).hitTestable(), findsOneWidget);
      }
      await binding.takeScreenshot('v2_home_2026');
      await tester.tap(find.byKey(const Key('glass_tab_3')));
      await frames(tester);
      expect(find.byKey(const Key('panchang_daily_overview')), findsOneWidget);
      await binding.takeScreenshot('v2_panchang_free');
      final lang = tester
          .element(find.byType(MaterialApp).first)
          .read<LanguageService>();
      final tracker = tester
          .element(find.byType(MaterialApp).first)
          .read<VratTrackerService>();
      expect(
        tracker.getRecordByUid('ekadashi:2026:01')?.note,
        'Archived private note',
      );
      final years = EkadashiService().getEkadashis(
        timezone: 'IST',
        languageCode: 'en',
      );
      final restartedTracker = VratTrackerService();
      await restartedTracker.init(occurrences: years);
      expect(restartedTracker.getRecord(1)?.note, 'Archived private note');
      await tester.tap(find.byIcon(Icons.spa_outlined));
      await frames(tester);
      await binding.takeScreenshot('v2_tracker_retained');
      await tester.tap(find.text('History'));
      await frames(tester);
      await binding.takeScreenshot('v2_history_2026');
      await tester.tap(find.byIcon(Icons.calendar_month));
      await frames(tester);
      final addButton = find.byKey(const Key('add_calendar_entry'));
      final capsule = tester.getRect(
        find.byKey(const Key('glass_capsule_surface')),
      );
      expect(
        tester.getRect(addButton).bottom,
        lessThanOrEqualTo(capsule.top - 8),
      );
      expect(addButton.hitTestable(), findsOneWidget);
      expect(
        tester
            .getRect(addButton)
            .overlaps(
              tester.getRect(
                find.byWidgetPredicate((widget) => widget is TableCalendar),
              ),
            ),
        isFalse,
        reason: 'Calendar actions must not obscure date targets',
      );
      await tester.tap(find.byKey(const Key('calendar_year_selector')));
      await frames(tester);
      await tester.tap(find.text('2027').last);
      await frames(tester);
      await binding.takeScreenshot('v2_calendar_2027');
      await lang.changeLanguage('te');
      await frames(tester);
      await binding.takeScreenshot('v2_calendar_telugu_2027');
      await tester.tap(find.byIcon(Icons.home));
      await frames(tester);
      await binding.takeScreenshot('v2_home_telugu');
      expect(tester.takeException(), isNull);
      for (final code in ['en', 'ta', 'hi', 'te']) {
        await lang.changeLanguage(code);
        await frames(tester, count: 10);
        final events = EkadashiService().getEkadashis(
          timezone: 'IST',
          languageCode: code,
        );
        final payload = WidgetSyncManager().buildPayload(
          ekadashiList: events,
          timezone: 'IST',
          locationName: 'Chennai',
          languageService: lang,
        );
        expect(
          await NativeWidgetService().sendWidgetPayload(jsonEncode(payload)),
          isTrue,
        );
        final fixtureDirectory = await getDatabasesPath();
        await Directory(fixtureDirectory).create(recursive: true);
        await File(
          '$fixtureDirectory/widget-fixture-$code.json',
        ).writeAsString(jsonEncode(payload));
        await tester.tap(find.byIcon(Icons.spa_outlined));
        await frames(tester);
        await binding.takeScreenshot('v2_vrat_$code');
        expect(find.text(lang.translate('vrat')), findsWidgets);
        await tester.tap(find.byIcon(Icons.search));
        await frames(tester);
        expect(find.byType(GlobalSearchScreen).hitTestable(), findsOneWidget);
        await binding.takeScreenshot('v2_search_$code');
        await tester.tap(find.byKey(const Key('global_search_back')));
        await frames(tester);
        await until(
          tester,
          () => find.byIcon(Icons.settings).evaluate().isNotEmpty,
        );
        await tester.tap(find.byIcon(Icons.settings));
        await frames(tester);
        await binding.takeScreenshot('glass_settings_dark_$code');
        await tester.tap(find.byType(SwitchListTile).first);
        await frames(tester);
        await binding.takeScreenshot('glass_settings_light_$code');
        await tester.tap(find.byType(SwitchListTile).first);
        await frames(tester);
        await tester.tap(find.byIcon(Icons.home));
        await frames(tester);
        await binding.takeScreenshot('glass_home_$code');
        await tester.tap(find.byIcon(Icons.calendar_month));
        await frames(tester);
        await binding.takeScreenshot('glass_calendar_$code');
      }
      await tester.tap(find.byIcon(Icons.search));
      await frames(tester);
      await lang.changeLanguage('en');
      await frames(tester, count: 10);
      // IntegrationTest defaults to real IME clients. Register controlled input
      // so repeated tester.enterText calls track the current TextInput client.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      await tester.enterText(find.byType(TextField), 'nirjla');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.arrow_forward).first);
      await frames(tester, count: 10);
      expect(
        SearchIndexManager().search('nirjla', languageCode: 'en'),
        isNotEmpty,
      );
      await binding.takeScreenshot('v2_search_typo');
      await tester.enterText(find.byType(TextField), 'zzzznomatch9999');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.arrow_forward).first);
      await frames(tester);
      await binding.takeScreenshot('v2_search_no_match');
      await until(
        tester,
        () => find.textContaining('No results found').evaluate().isNotEmpty,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'zzzznomatch9999',
      );
      debugPrint("Android Search typo and no-match UI verified");
      // Real Android SQLite + app screens, deterministic fake Google account.
      // OAuth consent and a real Google deletion remain an account/device check.
      final fixtureLang = LanguageService();
      await fixtureLang.changeLanguage('en');
      final fixtureTracker = VratTrackerService();
      await fixtureTracker.init(occurrences: years);
      // Dispose the app-owned connection before opening the same SQLite path.
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
      final repo = SqfliteCalendarEntryRepository();
      await repo.init();
      final google = AndroidTestGoogle();
      // Verification is asynchronous: a lazy provider initialized on the first
      // sync tap otherwise correctly opens the free user's paywall.
      final fixturePremium = PremiumService(entitlements: PremiumFixture());
      await fixturePremium.refresh();
      expect(fixturePremium.isPremium, isTrue);
      addTearDown(fixturePremium.dispose);
      Future<void> openCalendar() async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: fixturePremium),
              ChangeNotifierProvider.value(value: fixtureLang),
              ChangeNotifierProvider.value(value: fixtureTracker),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData.dark(),
              home: CalendarScreen(
                ekadashiList: years,
                repository: repo,
                googleService: GoogleCalendarService(
                  auth: google,
                  repository: repo,
                ),
              ),
            ),
          ),
        );
        await frames(tester);
        await until(
          tester,
          () =>
              tester
                  .widget<IconButton>(
                    find.byKey(const Key('add_calendar_entry')),
                  )
                  .onPressed !=
              null,
        );
      }

      await openCalendar();
      await tester.tap(find.byKey(const Key('calendar_year_selector')));
      await frames(tester);
      await tester.tap(find.text('2027').last);
      await frames(tester);
      // Select January 1 so deletion is visible in screenshots before/after.
      final state = tester.state<CalendarScreenState>(
        find.byType(CalendarScreen),
      );
      final calendar = find.byWidgetPredicate((w) => w is TableCalendar);
      expect(calendar, findsOneWidget);
      state.selectDate(DateTime(2027, 1, 1));
      await frames(tester);
      google.events = [
        event('Google event before deletion'),
        event('December event', start: '2027-12-31', end: '2028-01-01'),
      ];
      Future<void> sync() async {
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
        await tester.tap(importButton);
        await frames(tester);
        await until(
          tester,
          () => find.text('Import selected').evaluate().isNotEmpty,
        );
        await tester.tap(find.text('Import selected'));
        await frames(tester);
        await until(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
      }

      await sync();
      expect(google.min, DateTime(2027));
      expect(google.max, DateTime(2028));
      expect(
        (await repo.getForDay(
          DateTime(2027, 1, 1),
        )).map((entry) => entry.title),
        contains('Google event before deletion'),
        reason: 'The whole-year sync should persist the selected day event',
      );
      await tester.scrollUntilVisible(
        find.text('Google event before deletion'),
        220,
        scrollable: find
            .descendant(
              of: find.byType(CalendarScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await frames(tester);
      expect(find.text('Google event before deletion'), findsOneWidget);
      await binding.takeScreenshot('v2_google_before_delete');
      google.events = [
        event('December event', start: '2027-12-31', end: '2028-01-01'),
      ];
      await sync();
      expect(find.text('Google event before deletion'), findsNothing);
      expect(
        (await repo.getAll()).where((e) => e.title == 'December event'),
        hasLength(1),
      );
      await binding.takeScreenshot('v2_google_after_delete');
      debugPrint('Android full-year Google deletion reconciliation verified');
      await tester.tap(find.byKey(const Key('add_calendar_entry')));
      await frames(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'My private reminder',
      );
      await tester.tap(find.text('All day'));
      await frames(tester);
      await binding.takeScreenshot('v2_custom_editor');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await frames(tester);
      expect(
        (await repo.getForDay(
          DateTime(2027, 1, 1),
        )).map((entry) => entry.title),
        contains('My private reminder'),
        reason:
            'Saving the custom entry should persist it for the selected day',
      );
      final savedReminder = find.text('My private reminder');
      await tester.scrollUntilVisible(
        savedReminder,
        220,
        scrollable: find
            .descendant(
              of: find.byType(CalendarScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(savedReminder, findsOneWidget);
      await binding.takeScreenshot('v2_custom_saved');
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
      await repo.close();
      await repo.init();
      expect(
        (await repo.getAll()).where((e) => e.title == 'My private reminder'),
        hasLength(1),
      );
      await openCalendar();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
      await repo.close();
    },
  );
}
