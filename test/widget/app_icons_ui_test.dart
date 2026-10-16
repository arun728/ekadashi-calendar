import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The tab bar and Home's menus show the same symbols as on the iPhone
/// (RootView.swift and HomeControls in TodayView.swift).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() => harness.uninstall());

  IconData? iconIn(WidgetTester tester, Finder parent) => tester
      .widget<Icon>(
        find.descendant(of: parent, matching: find.byType(Icon)).first,
      )
      .icon;

  testWidgets('tab bar: house, calendar, rosette, sparkles, gear', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final expected = [
      AppIcons.tabHome,
      AppIcons.tabCalendar,
      AppIcons.tabJourney,
      AppIcons.tabPanchang,
      AppIcons.tabSettings,
    ];
    for (final (index, icon) in expected.indexed) {
      expect(
        iconIn(tester, find.byKey(Key('glass_tab_$index'))),
        icon,
        reason: 'tab $index',
      );
    }
  });

  testWidgets('Home menus: location, tradition, language and year', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(
      iconIn(tester, find.byKey(const Key('home_location'))),
      AppIcons.locationDetected,
    );
    expect(
      iconIn(tester, find.byKey(const Key('home_tradition_menu'))),
      AppIcons.homeTradition,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('language_menu')),
        matching: find.byIcon(AppIcons.homeLanguage),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home_year_menu')),
        matching: find.byIcon(AppIcons.homeYear),
      ),
      findsWidgets,
    );
  });
}
