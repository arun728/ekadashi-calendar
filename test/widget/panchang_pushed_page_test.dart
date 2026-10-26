import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../support/premium_fixture.dart';

/// Panchang opened from a search result (iOS pushes PanchangView in the
/// search's navigation stack): the teal AppBackground, an inline title and
/// Today in its own bar, without the removed notes action.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EkadashiService();

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting();
    ObservanceCalendarService.calculateInline = true;
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

  testWidgets('pushed Panchang paints AppBackground with Today and no notes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
    addTearDown(premium.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PanchangPushedPage(
                    title: 'Diwali',
                    initialDate: DateTime(2026, 11, 8),
                    initialCity: PanchangCity.newDelhi,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final page = find.byType(PanchangPushedPage);
    expect(
      find.descendant(of: page, matching: find.byType(AppBackground)),
      findsOneWidget,
    );
    final bar = find.descendant(of: page, matching: find.byType(AppBar));
    expect(
      find.descendant(of: bar, matching: find.text('Diwali')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.byKey(const Key('panchang_today')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.byKey(const Key('panchang_notes')),
      ),
      findsNothing,
    );
    expect(find.byIcon(AppIcons.back), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a festival result in Search opens the pushed Panchang', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final premium = PremiumService(entitlements: PremiumFixture());
    await premium.refresh();
    addTearDown(premium.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: MaterialApp(
          home: GlobalSearchScreen(
            ekadashiList: service.getEkadashis(
              timezone: 'IST',
              languageCode: 'en',
            ),
            ekadashisFor: (code) =>
                service.getEkadashis(timezone: 'IST', languageCode: code),
            availableYears: service.availableYears,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('global_search_field')),
      'Diwali',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final result = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'search_result_observance:deepavali:',
          ),
    );
    await tester.tap(result.first);
    await tester.pumpAndSettle();
    expect(find.byType(PanchangPushedPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PanchangPushedPage),
        matching: find.byType(AppBackground),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
