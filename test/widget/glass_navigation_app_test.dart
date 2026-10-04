import '../support/devotion_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';
import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() => harness.uninstall());
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Calendar Add button stays above glass at ${width}dp, scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(harness.app());
          await tester.pumpAndSettle();
          await tapAppTab(tester, 1);
          await tester.pumpAndSettle();
          final add = find.byKey(const Key('add_calendar_entry'));
          final capsule = tester.getRect(
            find.byKey(const Key('glass_capsule_surface')),
          );
          expect(
            tester.getRect(add).bottom,
            lessThanOrEqualTo(capsule.top - 8),
          );
          expect(add.hitTestable(), findsOneWidget);
          expect(tester.widget<IconButton>(add).onPressed, isNotNull);
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final month in [8, 10]) {
    for (final height in [720.0, 732.0]) {
      testWidgets(
        'Calendar empty day is readable above glass on a short ${height}dp screen, month $month',
        (tester) async {
          tester.view.physicalSize = Size(411, height);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          await tester.pumpWidget(harness.app());
          await tester.pumpAndSettle();
          await tapAppTab(tester, 1);
          await tester.pumpAndSettle();
          tester
              .state<CalendarScreenState>(find.byType(CalendarScreen))
              .selectDate(DateTime(2026, month, month == 8 ? 1 : 4));
          await tester.pumpAndSettle();
          final empty = find.text('No Ekadashi on this day');
          final capsule = tester.getRect(
            find.byKey(const Key('glass_capsule_surface')),
          );
          expect(
            tester.getRect(empty).bottom,
            lessThanOrEqualTo(capsule.top - 8),
          );
          expect(
            tester
                .getRect(find.byKey(const Key('add_calendar_entry')))
                .overlaps(
                  tester.getRect(
                    find.byWidgetPredicate((widget) => widget is TableCalendar),
                  ),
                ),
            isFalse,
            reason: 'Add must never cover calendar dates on short screens',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('iOS retains its existing navigation', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byKey(const Key('glass_navigation_bar')), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('Floating glass capsule keeps five tabs and their app state', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glass_navigation_bar')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('glass_tab_$i')).hitTestable(), findsOneWidget);
    }
    await tapAppTab(tester, 1);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_year_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027').last);
    await tester.pumpAndSettle();
    await openVrat(tester);
    await tester.pumpAndSettle();
    expect(find.byType(VratTrackerScreen).hitTestable(), findsOneWidget);
    await openSearch(tester);
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen).hitTestable(), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'parvsa');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tapAppTab(tester, 4);
    await tester.pumpAndSettle();
    expect(find.text('Enable Notifications'), findsOneWidget);
    await openSearch(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'parvsa',
    );
    await tapAppTab(tester, 1);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('calendar_year_selector')),
          )
          .value,
      2027,
    );
    await tapAppTab(tester, 1);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('calendar_year_selector')),
          )
          .value,
      [2026, 2027].contains(DateTime.now().year) ? DateTime.now().year : 2027,
    );
    final dynamic state = tester.state(find.byType(MainScreen, skipOffstage: false));
    state.handleDeepLink(Uri.parse('ekadashi://search'));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Global search stays readable with keyboard and restores navigation on close',
    (tester) async {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await openSearch(tester);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('glass_navigation_bar')).hitTestable(),
        findsNothing,
      );
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      tester.view.resetViewInsets();
      await returnToMain(tester);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('glass_tab_3')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
