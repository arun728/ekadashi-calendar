import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
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
  }) async {
    SharedPreferences.setMockInitialValues({'language_code': language});
    final lang = LanguageService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider<LanguageService>.value(value: lang),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PanchangScreen(
              initialDate: date,
              initialCity: PanchangCity.newDelhi,
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
    await showPanchang(tester, premium: premium);
    // Today's month; choose November 2026 with the month picker.
    await tester.tap(find.byKey(const Key('panchang_selected_month')));
    await tester.pumpAndSettle();
    while (find.text('2026').evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.chevron_left).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('panchang_month_11')));
    await tester.pumpAndSettle();
    // A picked month opens its first day, shown in full.
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
    expect(find.text('Smarta'), findsOneWidget);
    expect(find.text('Vaishnava · Gaudiya/ISKCON'), findsOneWidget);
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

  testWidgets('location menu and a validated custom location', (tester) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium, date: DateTime(2026, 10, 8));
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PanchangCity.mumbai.label).last);
    await tester.pumpAndSettle();
    expect(find.text(PanchangCity.mumbai.label), findsOneWidget);

    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Search city or use location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search city or use location'));
    await tester.pumpAndSettle();
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
    expect(find.text('New York'), findsOneWidget);
    expect(find.text('America/New_York'), findsOneWidget);
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
