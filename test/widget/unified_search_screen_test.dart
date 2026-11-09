import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Phase 1 on Android: one search over Ekadashis, festivals (locked for free
/// users), type words and the year filter.
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app() => MultiProvider(
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
      ),
    ),
  );

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

  testWidgets('Ekadashis, locked festivals and type words are found', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search_start')), findsOneWidget);

    await search(tester, 'Mohini');
    expect(result('ekadashi:'), findsWidgets);

    await search(tester, 'Diwali');
    expect(result('observance:deepavali:'), findsWidgets);
    expect(find.text('Unlock with Premium'), findsWidgets);

    await search(tester, 'amavasai');
    expect(result('observance:amavasya:'), findsWidgets);
    expect(result('ekadashi:'), findsNothing);

    await search(tester, 'zzzznomatch9999');
    expect(find.byKey(const Key('search_no_results')), findsOneWidget);
  });

  testWidgets('a type chip alone lists that type', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search_filter_ekadashi')));
    await tester.pumpAndSettle();
    expect(result('ekadashi:'), findsWidgets);
    expect(result('observance:'), findsNothing);
  });

  testWidgets(
    'lunar starts, exclusive categories and monthly naming reach Search',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await search(tester, 'amavasya 2026');
      expect(result('observance:amavasya:2026-11-08'), findsOneWidget);
      expect(result('observance:amavasya:2026-11-09'), findsNothing);

      await search(tester, 'guru purnima 2027');
      expect(result('observance:guru-purnima:'), findsWidgets);
      await search(tester, '2027');
      final purnima = find.byKey(const Key('search_filter_purnima'));
      await tester.ensureVisible(purnima);
      await tester.tap(purnima);
      await tester.pumpAndSettle();
      expect(result('observance:purnima:'), findsWidgets);
      expect(result('observance:guru-purnima:'), findsNothing);

      // Clear the explicit category, then verify the recurring title.
      await tester.tap(purnima);
      await tester.pumpAndSettle();
      await search(tester, 'monthly vinayaka chaturthi 2027');
      expect(find.text('Monthly Vinayaka Chaturthi'), findsWidgets);
      expect(result('observance:ganesh-chaturthi:'), findsNothing);
    },
  );
}
