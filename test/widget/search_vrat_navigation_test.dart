import 'package:ekadashi_calendar/widgets/glass_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
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
  testWidgets(
    'Search, Vrat and Settings all remain reachable; widget date opens correct archive year',
    (tester) async {
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final nav = tester.widget<GlassNavigationBar>(
        find.byType(GlassNavigationBar),
      );
      expect(nav.items, hasLength(5));
      final dynamic state = tester.state(find.byType(MainScreen));
      await tester.tap(find.byIcon(Icons.spa_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(VratTrackerScreen).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('open_global_search')));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalSearchScreen).hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzzznomatch9999');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('No results found'), findsOneWidget);
      state.handleDeepLink(Uri.parse('ekadashi://calendar?date=2027-01-07'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen).hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const Key('calendar_year_selector')),
            )
            .value,
        2027,
      );
      // PR #12's old More tab now lives inside Panchang.
      state.handleDeepLink(Uri.parse('ekadashi://more'));
      await tester.pumpAndSettle();
      expect(find.byType(PanchangScreen).hitTestable(), findsOneWidget);
      state.handleDeepLink(Uri.parse('ekadashi://search'));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalSearchScreen).hitTestable(), findsOneWidget);
      state.handleDeepLink(Uri.parse('http://settings'));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalSearchScreen).hitTestable(), findsOneWidget);
      expect(
        harness.widgetCalls.any((c) => c.method == 'updateWidgetData'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing focused Search restores the app navigation', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_global_search')));
    await tester.pumpAndSettle();
    expect(find.byType(GlobalSearchScreen), findsOneWidget);

    final searchField = find.byType(TextField).first;
    final focusNode = tester.widget<TextField>(searchField).focusNode!;
    await tester.showKeyboard(searchField);
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('global_search_back')));
    await tester.pumpAndSettle();

    expect(find.byType(GlobalSearchScreen), findsNothing);
    expect(focusNode.hasFocus, isFalse);
    expect(find.byKey(const Key('glass_navigation_bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
