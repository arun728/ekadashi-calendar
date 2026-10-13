import 'dart:async';

import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../support/premium_fixture.dart';

/// The Android Panchang (docs/ROADMAP.md Phases 2 and 3): Key days first,
/// a clean Daily page, Muhurta, calculated Ekadashi and Rashi, in the app
/// language, with Premium detail behind the paywall.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EkadashiService();

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting();
    await service.initializeData();
    // Read from disk now: assets never load on the widget tests' fake clock.
    await PanchangLocationStore.cities();
    ObservanceCalendarService.calculateInline = true;
    ObservanceCalendarService.instance.put(
      2026,
      PanchangCity.newDelhi,
      const PanchangEngine().observanceCalendar(
        2026,
        city: PanchangCity.newDelhi,
      ),
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PremiumService> premiumService(bool active) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = active,
    );
    if (active) await premium.refresh();
    return premium;
  }

  Future<void> showPanchang(
    WidgetTester tester, {
    required PremiumService premium,
    DateTime? date,
    String language = 'en',
    EkadashiSettings? settings,
    bool savedCity = false,
  }) async {
    SharedPreferences.setMockInitialValues({'language_code': language});
    final lang = LanguageService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider<LanguageService>.value(value: lang),
          ChangeNotifierProvider<EkadashiSettings>.value(
            value: settings ?? EkadashiSettings(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PanchangScreen(
              initialDate: date,
              initialCity: savedCity ? null : PanchangCity.newDelhi,
              ekadashiList: service.getEkadashis(
                timezone: 'IST',
                languageCode: language,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder pickerList() => find
      .descendant(
        of: find.byKey(const Key('city_picker_list')),
        matching: find.byType(Scrollable),
      )
      .first;

  Finder scrollable() => find
      .descendant(
        of: find.byKey(const Key('panchang_scroll_view')),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('free Daily shows the tithi, sun and moon and the upgrade card', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 10, 8));

    expect(find.byKey(const Key('panchang_daily_overview')), findsOneWidget);
    expect(find.byKey(const Key('panchang_tithi_title')), findsOneWidget);
    expect(find.byKey(const Key('panchang_sun_moon')), findsOneWidget);
    expect(find.text('Thu, 8 Oct 2026'), findsOneWidget);
    expect(find.text('IST · English'), findsNothing, reason: 'chip removed');
    await tester.scrollUntilVisible(
      find.byKey(const Key('panchang_unlock_button')),
      200,
      scrollable: scrollable(),
    );
    expect(find.byKey(const Key('panchang_limbs')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Key days come first: Ekadashis free, festivals locked', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 11, 1));
    await tester.tap(find.byKey(const Key('panchang_tab_keydays')));
    await tester.pumpAndSettle();
    // November 2026's Key days, under the selected date in full.
    expect(find.text('Sun, 1 Nov 2026'), findsOneWidget);
    expect(find.byKey(const Key('panchang_key_days')), findsOneWidget);
    expect(find.byKey(const Key('panchang_key_days_unlock')), findsOneWidget);
    expect(find.text('Deepavali (Lakshmi Puja)'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsWidgets);
    await tester.tap(find.byKey(const Key('panchang_key_filter_ekadashi')));
    await tester.pumpAndSettle();
    expect(find.text('Deepavali (Lakshmi Puja)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Ekadashi sub-tab calculates in a background isolate', (
    tester,
  ) async {
    // The app calculates off the UI thread; the closure it sends must not
    // carry the screen (12 Oct 2026: "Could not calculate this month").
    ObservanceCalendarService.calculateInline = false;
    addTearDown(() => ObservanceCalendarService.calculateInline = true);
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 11, 1));
    await tester.tap(find.byKey(const Key('panchang_tab_ekadashi')));
    // Let the page slide in (the spinner keeps pumpAndSettle busy).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    const fastDay = 'Fast';
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Could not calculate this month.').evaluate().isNotEmpty) {
        break;
      }
      if (find.text(fastDay).evaluate().isNotEmpty) break;
    }
    expect(find.text('Could not calculate this month.'), findsNothing);
    expect(find.text(fastDay), findsWidgets, reason: 'the fasts of the month');
  });

  testWidgets('a reminder opens its day even while the saved city loads', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    // On a phone the saved city arrives after the tapped reminder has
    // opened its day (Panchang is built when first opened); hold it back.
    final store = _SlowLocationStore();
    final key = GlobalKey<PanchangScreenState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider<LanguageService>.value(
            value: LanguageService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PanchangScreen(
              key: key,
              locationStore: store,
              ekadashiList: service.getEkadashis(
                timezone: 'IST',
                languageCode: 'en',
              ),
            ),
          ),
        ),
      ),
    );
    key.currentState!.showDate(DateTime(2027, 3, 4));
    await tester.pumpAndSettle();
    store.loaded.complete(PanchangCity.newDelhi);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('panchang_stepper')),
        matching: find.text('Thu, 4 Mar 2027'),
      ),
      findsOneWidget,
      reason: 'restoring the saved city must not reset the date to today',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every sub-tab shows the weekday, date, month and year', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 10, 8));
    Future<void> open(String page) async {
      await tester.tap(find.byKey(Key('panchang_tab_$page')));
      await tester.pumpAndSettle();
    }

    Finder dateOnPage(String text) => find.descendant(
      of: find.byKey(const Key('panchang_stepper')),
      matching: find.text(text),
    );
    for (final page in ['keydays', 'daily', 'muhurta', 'ekadashi', 'rashi']) {
      await open(page);
      expect(dateOnPage('Thu, 8 Oct 2026'), findsOneWidget, reason: page);
    }
    // The monthly sub-tabs step a month and keep the day of the month.
    await open('keydays');
    await tester.tap(find.byKey(const Key('panchang_next_month')));
    await tester.pumpAndSettle();
    expect(dateOnPage('Sun, 8 Nov 2026'), findsOneWidget);
    await open('daily');
    expect(dateOnPage('Sun, 8 Nov 2026'), findsOneWidget);
    // Days stepped on Daily carry over to the monthly sub-tabs.
    for (var i = 0; i < 22; i++) {
      await tester.tap(find.byKey(const Key('panchang_next_day')));
      await tester.pumpAndSettle();
    }
    expect(dateOnPage('Mon, 30 Nov 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('panchang_next_day')));
    await tester.pumpAndSettle();
    await open('ekadashi');
    expect(dateOnPage('Tue, 1 Dec 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('panchang_previous_month')));
    await tester.pumpAndSettle();
    expect(dateOnPage('Sun, 1 Nov 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium shows the five limbs, timings, Muhurta and Rashi', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 10, 8));
    expect(find.byKey(const Key('panchang_limbs')), findsOneWidget);
    for (final label in ['Tithi', 'Nakshatra', 'Yoga', 'Karana', 'Vara']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('panchang_more_details')),
      300,
      scrollable: scrollable(),
    );
    expect(find.text('Rahu Kalam'), findsOneWidget);
    await tester.tap(find.byKey(const Key('panchang_tab_muhurta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panchang_day_night')), findsOneWidget);
    expect(find.text('Choghadiya'), findsOneWidget);
    await tester.tap(find.byKey(const Key('panchang_tab_rashi')));
    await tester.pumpAndSettle();
    expect(find.text('Sun rashi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('panchang_tab_ekadashi')));
    await tester.pumpAndSettle();
    // "Smarta" or "Vaishnava" everywhere.
    expect(find.text('Smarta'), findsOneWidget);
    expect(find.text('Vaishnava'), findsOneWidget);
    expect(find.textContaining('Gaudiya'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Panchang follows the app language', (tester) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    await showPanchang(
      tester,
      premium: premium,
      date: DateTime(2026, 10, 8),
      language: 'hi',
    );
    expect(find.text('तिथि'), findsWidgets);
    expect(find.text('नक्षत्र'), findsWidgets);
    expect(find.text('Tithi'), findsNothing);
    expect(find.text('Nakshatra'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every sub-tab opens the full calendar to pick a date', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 10, 8));
    for (final (page, key) in [
      ('keydays', 'panchang_selected_month'),
      ('daily', 'panchang_selected_date'),
      ('muhurta', 'panchang_selected_date'),
      ('ekadashi', 'panchang_selected_month'),
      ('rashi', 'panchang_selected_date'),
    ]) {
      await tester.ensureVisible(find.byKey(Key('panchang_tab_$page')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('panchang_tab_$page')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget, reason: page);
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('20'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // The picked day on this sub-tab; the monthly ones browse its month.
      expect(find.text('Tue, 20 Oct 2026'), findsOneWidget, reason: page);
      await tester.tap(find.byKey(const Key('panchang_today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('panchang_month_picker')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Home city picker with time zones and a custom location', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 10, 8));
    String? text(String key) => tester.widget<Text>(find.byKey(Key(key))).data;
    expect(text('panchang_city_name'), 'New Delhi');
    expect(text('panchang_city_zone'), 'IST');

    // Nothing typed: popular cities, every one with its time zone.
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ekadashi_location_search')), findsOneWidget);
    expect(
      find.byKey(const Key('ekadashi_location_current_button')),
      findsOneWidget,
    );
    expect(find.text('Popular cities'), findsOneWidget);
    final london = find.byKey(const Key('ekadashi_city_geonames-2643743'));
    await tester.scrollUntilVisible(london, 300, scrollable: pickerList());
    // London shows GMT or BST by season.
    expect(
      find.descendant(
        of: london,
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data == 'GMT' || w.data == 'BST'),
        ),
      ),
      findsOneWidget,
    );

    // A search result moves the Panchang there.
    await tester.scrollUntilVisible(
      find.byKey(const Key('ekadashi_location_search')),
      -300,
      scrollable: pickerList(),
    );
    await tester.enterText(
      find.byKey(const Key('ekadashi_location_search')),
      'Mumbai',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ekadashi_city_geonames-1275339')));
    await tester.pumpAndSettle();
    expect(text('panchang_city_name'), 'Mumbai (IN)');
    expect(text('panchang_city_zone'), 'IST');

    // The pick is a recent search next time; coordinates typed by hand
    // are validated.
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();
    expect(find.text('Recent Searches'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('location_save')),
      400,
      scrollable: pickerList(),
    );
    await tester.enterText(find.byKey(const Key('location_name')), 'New York');
    await tester.enterText(find.byKey(const Key('location_latitude')), '400');
    await tester.enterText(
      find.byKey(const Key('location_longitude')),
      '-74.006',
    );
    await tester.enterText(
      find.byKey(const Key('location_timezone')),
      'America/New_York',
    );
    await tester.tap(find.byKey(const Key('location_save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from -90 to 90'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('location_latitude')),
      '40.7128',
    );
    await tester.tap(find.byKey(const Key('location_save')));
    await tester.pumpAndSettle();
    expect(text('panchang_city_name'), 'New York');
    // Every city shows its time zone like IST, never the IANA name.
    expect(text('panchang_city_zone'), anyOf('EDT', 'EST'));
    expect(find.text('America/New_York'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a city chosen on Home moves the Panchang tab, not the reverse', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    final settings = EkadashiSettings();
    await showPanchang(
      tester,
      premium: premium,
      settings: settings,
      savedCity: true,
    );
    final cities = await PanchangLocationStore.cities();
    final london = cities.firstWhere((c) => c.id == 'geonames-2643743');
    await tester.runAsync(() => settings.chooseCity(london));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('panchang_city_name'))).data,
      'London (GB)',
    );
    // Choosing on the Panchang tab leaves Home's city alone.
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ekadashi_location_search')),
      'Mumbai',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ekadashi_city_geonames-1275339')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('panchang_city_name'))).data,
      'Mumbai (IN)',
    );
    expect(settings.city.id, 'geonames-2643743');
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen with large text has no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 10, 8));
    for (final page in ['daily', 'muhurta', 'rashi', 'keydays']) {
      await tester.tap(find.byKey(Key('panchang_tab_$page')));
      await tester.pumpAndSettle();
      await tester.drag(scrollable(), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: page);
    }
  });

  testWidgets('free Tamil on a narrow screen with large text has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, language: 'ta');
    for (final page in ['keydays', 'daily', 'muhurta', 'ekadashi', 'rashi']) {
      await tester.ensureVisible(find.byKey(Key('panchang_tab_$page')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('panchang_tab_$page')));
      await tester.pumpAndSettle();
      await tester.drag(scrollable(), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: page);
    }
  });
}

class _SlowLocationStore extends PanchangLocationStore {
  final loaded = Completer<PanchangCity?>();

  @override
  Future<PanchangCity?> load() => loaded.future;
}
