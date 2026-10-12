import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
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
/// Today and the calculation notes in its own bar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting();
    ObservanceCalendarService.calculateInline = true;
  });

  testWidgets('pushed Panchang paints AppBackground with Today and notes', (
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
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
