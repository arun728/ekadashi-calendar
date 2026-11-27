import 'package:ekadashi_calendar/services/display_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Arun, 27 November 2026: with 2027 picked on Home, All years stayed on
/// January 2027's first Ekadashi. All years always opens on the next one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() {
    DisplayClock.setTestClock(null);
    harness.uninstall();
  });

  Future<void> pickYear(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const Key('home_year_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  String indicator(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('home_page_indicator'))).data!;

  testWidgets('All years opens on the next Ekadashi, also after 2027 was '
      'picked or another card was browsed', (tester) async {
    DisplayClock.setTestClock(() => DateTime.utc(2026, 11, 27, 4, 30));
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.text('Utpanna Ekadashi'), findsWidgets);

    await pickYear(tester, '2027');
    expect(find.text('Saphala Ekadashi'), findsWidgets);
    expect(indicator(tester), '1 / 25');

    await pickYear(tester, 'All years');
    expect(find.text('Utpanna Ekadashi'), findsWidgets);
    expect(indicator(tester), '23 / 49');

    // From the current year after browsing back a card, too.
    await pickYear(tester, '2026');
    await tester.tap(find.byKey(const Key('home_previous')));
    await tester.pumpAndSettle();
    expect(indicator(tester), '22 / 24');
    await pickYear(tester, 'All years');
    expect(indicator(tester), '23 / 49');
    expect(tester.takeException(), isNull);
  });
}
