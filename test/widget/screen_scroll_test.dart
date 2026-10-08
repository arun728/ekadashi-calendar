import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';

import '../support/app_harness.dart';

/// Long screens scroll when dragged from their top half, not only from the
/// lowest card (the Android Calendar bug, docs/ROADMAP.md Phase 4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() => harness.uninstall());

  Future<void> open(WidgetTester tester, int tab) async {
    tester.view.physicalSize = const Size(393, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('glass_tab_$tab')));
    await tester.pumpAndSettle();
  }

  /// Drags up from [start] and expects the page holding [anchor] to scroll.
  Future<void> expectScrolls(
    WidgetTester tester,
    Finder anchor,
    Offset start,
  ) async {
    final position = Scrollable.of(tester.element(anchor)).position;
    final before = position.pixels;
    await tester.dragFrom(start, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(before));
  }

  testWidgets('Calendar scrolls when dragged on the month grid', (
    tester,
  ) async {
    await open(tester, 1);
    final grid = find.byWidgetPredicate((w) => w is TableCalendar);
    expect(grid, findsOneWidget);
    await expectScrolls(
      tester,
      find.byKey(const Key('calendar_month_tube')),
      tester.getCenter(grid),
    );
  });

  testWidgets('Panchang scrolls when dragged from the top half', (
    tester,
  ) async {
    await open(tester, 3);
    await tester.tap(find.byKey(const Key('panchang_tab_daily')));
    await tester.pumpAndSettle();
    await expectScrolls(
      tester,
      find.byKey(const Key('panchang_daily_overview')),
      const Offset(196, 260),
    );
  });

  testWidgets('Settings scrolls when dragged from the top half', (
    tester,
  ) async {
    await open(tester, 4);
    await expectScrolls(
      tester,
      find.byKey(const Key('settings_appearance_tube')),
      const Offset(196, 260),
    );
  });

  testWidgets('Journey scrolls when dragged from the top half', (tester) async {
    await open(tester, 2);
    await expectScrolls(
      tester,
      find.byKey(const Key('journey_overview_streaks')),
      const Offset(196, 300),
    );
  });
}
