import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/services/display_clock.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install(preferences: {EkadashiSettings.yearKey: 2026});
  });
  tearDown(() {
    DisplayClock.setTestClock(null);
    return harness.uninstall();
  });

  final menu = find.byKey(const Key('home_year_menu'));
  Finder homeYear(String year) =>
      find.descendant(of: menu, matching: find.text(year));

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('All years leads the menu and survives Parana rollover', (
    tester,
  ) async {
    var now = DateTime.parse('2026-12-21T10:12:59+05:30');
    DisplayClock.setTestClock(() => now);
    await tester.pumpWidget(harness.app());
    await frames(tester);
    expect(homeYear('2026'), findsOneWidget);
    await tester.tap(menu);
    await frames(tester);
    final allYears = find.widgetWithText(PopupMenuItem<int>, 'All years');
    final newer = find.widgetWithText(PopupMenuItem<int>, '2027');
    final older = find.widgetWithText(PopupMenuItem<int>, '2026');
    expect(allYears, findsOneWidget);
    expect(
      tester.getTopLeft(allYears).dy,
      lessThan(tester.getTopLeft(newer).dy),
    );
    expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(older).dy));
    await tester.tap(allYears);
    await frames(tester);
    expect(homeYear('All years'), findsOneWidget);
    expect(find.text('24 / 49'), findsOneWidget);

    now = DateTime.parse('2026-12-21T10:13:00+05:30');
    (tester.state(find.byType(MainScreen)) as dynamic).refreshLifecycle();
    await frames(tester);
    expect(homeYear('All years'), findsOneWidget);
    expect(find.text('25 / 49'), findsOneWidget);
    expect(find.text('Sun, 3 Jan 2027'), findsWidgets);
  });

  testWidgets(
    'Calendar opens on today after December Home advances to January',
    (tester) async {
      DisplayClock.setTestClock(
        () => DateTime.parse('2026-12-21T11:00:00+05:30'),
      );
      await tester.pumpWidget(harness.app());
      await frames(tester);
      expect(homeYear('2027'), findsOneWidget);
      await tester.tap(find.byKey(const Key('glass_tab_1')));
      await frames(tester);
      final calendar = find.byKey(const Key('calendar_year_selector'));
      expect(
        find.descendant(of: calendar, matching: find.text('Mon, 21 Dec 2026')),
        findsOneWidget,
      );
    },
  );

  testWidgets('January defaults apply to Search and Journey', (tester) async {
    DisplayClock.setTestClock(
      () => DateTime.parse('2027-01-01T12:00:00+05:30'),
    );
    await tester.pumpWidget(harness.app());
    await frames(tester);
    expect(homeYear('2027'), findsOneWidget);
    await tester.tap(find.byKey(const Key('glass_tab_2')));
    await frames(tester);
    final journey = find.byKey(const Key('journey_overview_year'));
    expect(
      find.descendant(of: journey, matching: find.text('2027')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('open_global_search')));
    await frames(tester);
    final search = find.byKey(const Key('search_year_selector'));
    expect(
      find.descendant(of: search, matching: find.text('2027')),
      findsOneWidget,
    );
  });
}
