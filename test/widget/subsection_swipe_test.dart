import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:ekadashi_calendar/services/search/search_return.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/widgets/glass_tube.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../support/premium_fixture.dart';

/// Panchang, Journey and Search sub-sections change with a horizontal swipe
/// as well as their chips, and Journey uses Panchang's glass chips
/// (docs/ROADMAP.md Phase 9).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EkadashiService();

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting();
    await service.initializeData();
    ObservanceCalendarService.calculateInline = true;
    for (final year in service.availableYears) {
      ObservanceCalendarService.instance.put(
        year,
        PanchangCity.newDelhi,
        const PanchangEngine().observanceCalendar(
          year,
          city: PanchangCity.newDelhi,
        ),
      );
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
  }

  bool selected(WidgetTester tester, String key) =>
      tester.widget<GlassFilterChip>(find.byKey(Key(key))).selected;

  /// Chips past the screen edge are scrolled into view first, as by hand.
  Future<void> tapChip(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> swipe(WidgetTester tester, {required bool left}) async {
    await tester.fling(
      find.byType(PageView),
      Offset(left ? -400 : 400, 0),
      1500,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Panchang sections change with a swipe', (tester) async {
    phone(tester);
    final premium = PremiumService(entitlements: PremiumFixture());
    addTearDown(premium.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PanchangScreen(
              initialCity: PanchangCity.newDelhi,
              ekadashiList: service.getEkadashis(
                timezone: 'IST',
                languageCode: 'en',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected(tester, 'panchang_tab_keydays'), isTrue);
    expect(find.byKey(const Key('panchang_next_month')), findsOneWidget);

    await swipe(tester, left: true);
    expect(selected(tester, 'panchang_tab_daily'), isTrue);
    expect(find.byKey(const Key('panchang_next_day')), findsOneWidget);
    expect(find.byKey(const Key('panchang_daily_overview')), findsOneWidget);

    await swipe(tester, left: true);
    expect(selected(tester, 'panchang_tab_muhurta'), isTrue);
    await swipe(tester, left: false);
    await swipe(tester, left: false);
    expect(selected(tester, 'panchang_tab_keydays'), isTrue);

    // A chip still jumps straight to its section.
    await tapChip(tester, 'panchang_tab_rashi');
    expect(selected(tester, 'panchang_tab_rashi'), isTrue);
    expect(find.byKey(const Key('panchang_unlock_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Journey uses glass chips like Panchang and swipes', (
    tester,
  ) async {
    phone(tester);
    final events = service.getEkadashis(timezone: 'IST', languageCode: 'en');
    final tracker = VratTrackerService();
    await tracker.init(occurrences: events);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tracker),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VratTrackerScreen(
              ekadashiList: events,
              currentTimezone: 'IST',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vrat_tabs_tube')), findsOneWidget);
    expect(find.byType(TabBar), findsNothing, reason: 'no Material tab bar');
    for (final page in ['overview', 'history', 'statistics', 'achievements']) {
      expect(find.byKey(Key('journey_tab_$page')), findsOneWidget);
    }
    expect(selected(tester, 'journey_tab_overview'), isTrue);
    expect(find.byKey(const Key('journey_overview_streaks')), findsOneWidget);

    await swipe(tester, left: true);
    expect(selected(tester, 'journey_tab_history'), isTrue);
    expect(find.byKey(const Key('vrat_history_filters_tube')), findsOneWidget);
    await swipe(tester, left: true);
    expect(selected(tester, 'journey_tab_statistics'), isTrue);
    await tapChip(tester, 'journey_tab_achievements');
    expect(selected(tester, 'journey_tab_achievements'), isTrue);
    expect(find.text('First Vrat'), findsOneWidget);
    await swipe(tester, left: false);
    expect(selected(tester, 'journey_tab_statistics'), isTrue);
    expect(tester.takeException(), isNull);
  });

  Widget searchApp({SearchSession? session}) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeService()),
      ChangeNotifierProvider(create: (_) => LanguageService()),
    ],
    child: MaterialApp(
      home: GlobalSearchScreen(
        ekadashiList: service.getEkadashis(timezone: 'IST', languageCode: 'en'),
        ekadashisFor: (code) =>
            service.getEkadashis(timezone: 'IST', languageCode: code),
        availableYears: service.availableYears,
        initialSession: session,
      ),
    ),
  );

  Finder result(String prefix) => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('search_result_$prefix'),
  );

  testWidgets('Search type pages change with a swipe', (tester) async {
    phone(tester);
    await tester.pumpWidget(searchApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('global_search_field')),
      'ekadashi',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(selected(tester, 'search_filter_all'), isTrue);
    expect(result('ekadashi:'), findsWidgets);

    await swipe(tester, left: true);
    final first = SearchCategory.filters.first.raw;
    expect(selected(tester, 'search_filter_$first'), isTrue);
    expect(selected(tester, 'search_filter_all'), isFalse);
    await swipe(tester, left: false);
    expect(selected(tester, 'search_filter_all'), isTrue);

    // The selected type's chip goes back to All.
    await tapChip(tester, 'search_filter_festival');
    expect(selected(tester, 'search_filter_festival'), isTrue);
    await tapChip(tester, 'search_filter_festival');
    expect(selected(tester, 'search_filter_all'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search reopens with the text, type and year it had', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      searchApp(
        session: const SearchSession(
          query: 'mohini',
          category: SearchCategory.ekadashi,
          year: 2027,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('global_search_field')),
    );
    expect(field.controller!.text, 'mohini');
    expect(selected(tester, 'search_filter_ekadashi'), isTrue);
    expect(find.text('2027'), findsWidgets);
    expect(result('ekadashi:2027'), findsWidgets);
    expect(result('ekadashi:2026'), findsNothing);
  });
}
