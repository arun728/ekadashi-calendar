import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/widgets/app_background.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../support/premium_fixture.dart';

/// Search looks like the iOS GlobalSearchView sheet: a chevron to close,
/// the inline title, the system search field below it, separate glass
/// filter controls, glass result rows and pages that stay in the sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EkadashiService();

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting();
    await service.initializeData();
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

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'ec2_recent_searches_list': ['Mohini'],
    }),
  );

  /// The search opened as the app opens it: a nested sheet.
  Future<void> open(WidgetTester tester, {bool premium = false}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final source = PremiumFixture()..premium = premium;
    final premiumService = PremiumService(entitlements: source);
    if (premium) premiumService.applyOwned({PremiumService.subscriptionId});
    addTearDown(premiumService.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => LanguageService()),
          ChangeNotifierProvider<PremiumService?>.value(value: premiumService),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open'),
                  onPressed: () => showAppSheet<void>(
                    context,
                    nested: true,
                    builder: (_) => GlobalSearchScreen(
                      ekadashiList: service.getEkadashis(
                        timezone: 'IST',
                        languageCode: 'en',
                      ),
                      ekadashisFor: (code) => service.getEkadashis(
                        timezone: 'IST',
                        languageCode: code,
                      ),
                      availableYears: service.availableYears,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('global_search_field')), text);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Finder result(String prefix) => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('search_result_$prefix'),
  );

  testWidgets('the sheet bar: chevron down, inline title, field below', (
    tester,
  ) async {
    await open(tester);
    final close = find.byKey(const Key('global_search_back'));
    expect(
      find.descendant(
        of: close,
        matching: find.byIcon(Icons.keyboard_arrow_down),
      ),
      findsOneWidget,
    );
    expect(find.text('Search'), findsOneWidget);
    // The field is not the bar's title: it sits below the title.
    final field = find.byKey(const Key('global_search_field'));
    expect(
      find.descendant(of: find.byType(AppBar), matching: field),
      findsNothing,
    );
    expect(
      tester.getTopLeft(field).dy,
      greaterThan(tester.getBottomLeft(find.text('Search')).dy),
    );
    // The system search field: a magnifier, no autofocus, a clear button.
    expect(tester.widget<TextField>(field).autofocus, isFalse);
    expect(
      find.descendant(
        of: find.byKey(const Key('global_search_bar')),
        matching: find.byIcon(Icons.search),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('global_search_clear')), findsNothing);
    await tester.enterText(field, 'Mohini');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('global_search_clear')), findsOneWidget);
    // The sheet paints the app background.
    expect(
      find.descendant(
        of: find.byType(GlobalSearchScreen),
        matching: find.byType(AppBackground),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters are separate glass controls coloured by category', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('search_filters_tube')), findsOneWidget);
    expect(find.byKey(const Key('search_categories_tube')), findsOneWidget);
    // The year menu is its own glass capsule with a calendar icon.
    final year = find.byKey(const Key('search_year_selector'));
    expect(
      find.descendant(of: year, matching: find.byType(GlassPanel)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: year, matching: find.byIcon(Icons.calendar_today)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: year, matching: find.byIcon(Icons.arrow_drop_down)),
      findsNothing,
    );
    // Each type is a GlassChip; the selected one takes its own colour.
    final ekadashi = find.byKey(const Key('search_filter_ekadashi'));
    expect(tester.widget(ekadashi), isA<GlassChip>());
    expect(
      tester.widget(find.byKey(const Key('search_filter_all'))),
      isA<GlassChip>(),
    );
    expect(tester.widget<GlassChip>(ekadashi).selected, isFalse);
    await tester.tap(ekadashi);
    await tester.pumpAndSettle();
    final chip = tester.widget<GlassChip>(ekadashi);
    expect(chip.selected, isTrue);
    expect(chip.color, Color(SearchCategory.ekadashi.color));
    expect(tester.takeException(), isNull);
  });

  testWidgets('start: recent searches and glass explore chips', (tester) async {
    await open(tester);
    final caption = tester.widget<Text>(find.text('RECENT SEARCHES'));
    expect(caption.style?.fontSize, IosText.caption);
    expect(caption.style?.fontWeight, FontWeight.w700);
    final clear = tester.widget<Text>(find.text('Clear All'));
    expect(clear.style?.fontSize, IosText.caption);
    expect(clear.style?.color, IosColors.teal);
    final recent = find.byKey(const Key('search_recent_Mohini'));
    expect(
      find.descendant(of: recent, matching: find.byIcon(Icons.history)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: recent, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
    // A compact row, not a 56 dp list tile.
    expect(
      find.descendant(of: recent, matching: find.byType(ListTile)),
      findsNothing,
    );
    expect(tester.getSize(recent).height, lessThan(48));
    final explore = find.byKey(const Key('search_explore_tube'));
    expect(
      find.descendant(of: explore, matching: find.byType(GlassChip)),
      findsNWidgets(SearchCategory.filters.length),
    );
    expect(
      find.descendant(of: explore, matching: find.byType(ActionChip)),
      findsNothing,
    );
    final prompt = tester.widget<Text>(
      find.text(
        tester
            .element(explore)
            .read<LanguageService>()
            .translate('search_start_all'),
      ),
    );
    expect(prompt.style?.fontSize, IosText.headline);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no results: the iOS unavailable view with the query', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'zzzznomatch9999');
    final empty = find.byKey(const Key('search_no_results'));
    expect(empty, findsOneWidget);
    expect(tester.widget(empty), isA<UnavailableView>());
    final view = tester.widget<UnavailableView>(empty);
    expect(view.icon, Icons.search);
    expect(view.title, 'No results found for "zzzznomatch9999"');
    expect(tester.takeException(), isNull);
  });

  testWidgets('results are glass rows with the iOS sizes and amber lock', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'Mohini');
    final row = result('ekadashi:').first;
    expect(tester.widget(row), isA<GlassPanel>());
    expect(tester.widget<GlassPanel>(row).radius, 16);
    final title = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .first;
    expect(title.style?.fontSize, IosText.headline);
    expect(title.style?.fontWeight, FontWeight.w600);
    final date = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .elementAt(1);
    expect(date.style?.fontSize, IosText.subheadline);

    await search(tester, 'Diwali');
    final locked = result('observance:deepavali:').first;
    final locks = tester.widgetList<Icon>(
      find.descendant(of: locked, matching: find.byIcon(Icons.lock)),
    );
    expect(locks, isNotEmpty);
    expect(locks.every((icon) => icon.color == IosColors.amber), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pages a result opens stay in the sheet on the background', (
    tester,
  ) async {
    await open(tester, premium: true);
    await search(tester, 'Mohini');
    await tester.tap(result('ekadashi:').first);
    await tester.pumpAndSettle();
    final details = find.byType(DetailsScreen);
    expect(details, findsOneWidget);
    expect(
      find.ancestor(of: details, matching: find.byType(BottomSheet)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: details, matching: find.byType(AppBackground)),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await search(tester, 'Diwali');
    await tester.tap(result('observance:deepavali:').first);
    await tester.pumpAndSettle();
    final panchang = find.byType(PanchangScreen);
    expect(panchang, findsOneWidget);
    expect(
      find.ancestor(of: panchang, matching: find.byType(BottomSheet)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: panchang, matching: find.byType(AppBackground)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
