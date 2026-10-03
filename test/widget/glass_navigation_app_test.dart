import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.tap(find.byKey(const Key('glass_tab_1')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_year_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('glass_tab_2')));
    await tester.pumpAndSettle();
    expect(find.byType(VratTrackerScreen).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('glass_tab_3')));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen).hitTestable(), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'parvsa');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('glass_tab_4')));
    await tester.pumpAndSettle();
    expect(find.text('Enable Notifications'), findsOneWidget);
    await tester.tap(find.byKey(const Key('glass_tab_3')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'parvsa',
    );
    await tester.tap(find.byKey(const Key('glass_tab_1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('calendar_year_selector')),
          )
          .value,
      2027,
    );
    await tester.tap(find.byKey(const Key('glass_tab_1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('calendar_year_selector')),
          )
          .value,
      [2026, 2027].contains(DateTime.now().year) ? DateTime.now().year : 2027,
    );
    final dynamic state = tester.state(find.byType(MainScreen));
    state.handleDeepLink(Uri.parse('ekadashi://search'));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Keyboard editing hides the capsule and restores it after dismissal',
    (tester) async {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('glass_tab_3')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('glass_navigation_bar')), findsNothing);
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('glass_tab_3')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
