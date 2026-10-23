import 'package:ekadashi_calendar/widgets/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Wide screens (a foldable's inner screen, the iPhone Duo's) put two panes
/// side by side; phones and outer screens keep one column
/// (docs/FOLDABLES.md, AdaptiveLayoutUITests on iOS).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phone = Size(393, 852);
  const outer = Size(466, 678);
  const innerPortrait = Size(669, 951);
  const innerLandscape = Size(951, 669);

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  Rect box(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(Key(key)));

  void expectSideBySide(WidgetTester tester, String first, String second) {
    final leading = box(tester, first), trailing = box(tester, second);
    expect(
      leading.right,
      lessThanOrEqualTo(trailing.left + 1),
      reason: '$first is left of $second',
    );
    expect(
      leading.top,
      moreOrLessEquals(trailing.top, epsilon: 1),
      reason: '$first and $second start together',
    );
  }

  void expectStacked(WidgetTester tester, String first, String second) {
    expect(
      box(tester, first).bottom,
      lessThanOrEqualTo(box(tester, second).top + 1),
      reason: '$second is below $first',
    );
  }

  group('AdaptivePanes', () {
    Widget panes() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdaptivePanes(
            leading: const _Counter(key: Key('left')),
            trailing: Container(key: const Key('right'), height: 40),
          ),
        ),
      ),
    );

    testWidgets('stack on phones and sit side by side on wide screens', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      for (final size in [phone, outer]) {
        setSize(tester, size);
        await tester.pumpWidget(panes());
        expectStacked(tester, 'left', 'right');
      }
      for (final size in [innerPortrait, innerLandscape]) {
        setSize(tester, size);
        await tester.pumpWidget(panes());
        expectSideBySide(tester, 'left', 'right');
        expect(
          box(tester, 'left').width,
          moreOrLessEquals(box(tester, 'right').width, epsilon: 1),
        );
      }
    });

    testWidgets('unfolding and folding keep each pane\'s state', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      setSize(tester, outer);
      await tester.pumpWidget(panes());
      await tester.tap(find.byKey(const Key('left')));
      await tester.tap(find.byKey(const Key('left')));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      setSize(tester, innerPortrait);
      await tester.pump();
      expectSideBySide(tester, 'left', 'right');
      expect(find.text('2'), findsOneWidget);
      setSize(tester, outer);
      await tester.pump();
      expectStacked(tester, 'left', 'right');
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('AdaptiveGrid lays out one column on phones and two on wide '
        'screens', (tester) async {
      addTearDown(tester.view.reset);
      Widget grid() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdaptiveGrid(
              spacing: 10,
              children: [
                for (var i = 0; i < 3; i++)
                  SizedBox(key: Key('cell$i'), height: 20 + i * 10.0),
              ],
            ),
          ),
        ),
      );
      setSize(tester, phone);
      await tester.pumpWidget(grid());
      expect(box(tester, 'cell1').top, box(tester, 'cell0').bottom + 10);
      expect(box(tester, 'cell0').width, 393);
      setSize(tester, innerPortrait);
      await tester.pumpWidget(grid());
      expectSideBySide(tester, 'cell0', 'cell1');
      expect(box(tester, 'cell1').left, box(tester, 'cell0').right + 10);
      // A row is as tall as its tallest cell.
      expect(box(tester, 'cell2').top, box(tester, 'cell1').bottom + 10);
      expect(box(tester, 'cell2').left, 0);
    });

    testWidgets('readable content stops at 720 and stays centred', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      setSize(tester, innerLandscape);
      await tester.pumpWidget(
        const MaterialApp(
          home: ReadableWidth(child: SizedBox(key: Key('text'), height: 10)),
        ),
      );
      final rect = box(tester, 'text');
      expect(rect.width, 720);
      expect(rect.left, moreOrLessEquals(115.5));
    });
  });

  group('the app', () {
    late AppHarness harness;
    setUp(() async {
      harness = AppHarness();
      await harness.install();
    });
    tearDown(() => harness.uninstall());

    Future<void> launch(WidgetTester tester, Size size) async {
      setSize(tester, size);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
    }

    Future<void> openTab(WidgetTester tester, int index) async {
      await tester.tap(find.byKey(Key('glass_tab_$index')));
      await tester.pumpAndSettle();
    }

    testWidgets('Home lists the year beside the card on wide screens only', (
      tester,
    ) async {
      await launch(tester, phone);
      expect(find.byKey(const Key('home_list_pane')), findsNothing);
      await tester.pumpWidget(const SizedBox());

      await launch(tester, innerPortrait);
      expectSideBySide(tester, 'home_card_pane', 'home_list_pane');
      final indicator = find.byKey(const Key('home_page_indicator'));
      final before = tester.widget<Text>(indicator).data;
      // A tap on another Ekadashi opens its card.
      final other = find.byKey(const Key('home_list_row_0'));
      await tester.ensureVisible(other);
      await tester.pumpAndSettle();
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(indicator).data, startsWith('1 / '));
      expect(
        before,
        isNot(startsWith('1 / ')),
        reason: 'Home opens on the current Ekadashi, not the first',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Calendar shows the month beside the selected day', (
      tester,
    ) async {
      await launch(tester, innerLandscape);
      await openTab(tester, 1);
      expectSideBySide(tester, 'calendar_grid_pane', 'calendar_day_pane');
      await tester.pumpWidget(const SizedBox());

      await launch(tester, phone);
      await openTab(tester, 1);
      expectStacked(tester, 'calendar_grid_pane', 'calendar_day_pane');
      expect(tester.takeException(), isNull);
    });

    testWidgets('folding keeps the Calendar month', (tester) async {
      await launch(tester, innerPortrait);
      await openTab(tester, 1);
      await tester.tap(find.byKey(const Key('calendar_next_month')));
      await tester.pumpAndSettle();
      String title() => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('calendar_year_selector')),
              matching: find.byType(Text),
            ),
          )
          .first
          .data!;
      final before = title();
      setSize(tester, outer);
      await tester.pumpAndSettle();
      expectStacked(tester, 'calendar_grid_pane', 'calendar_day_pane');
      expect(title(), before);
      setSize(tester, innerPortrait);
      await tester.pumpAndSettle();
      expect(title(), before);
    });

    testWidgets('Journey overview splits metrics and recording', (
      tester,
    ) async {
      await launch(tester, innerPortrait);
      await openTab(tester, 2);
      expectSideBySide(
        tester,
        'journey_overview_metrics_pane',
        'journey_overview_record_pane',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Panchang Daily shows two columns', (tester) async {
      await launch(tester, innerPortrait);
      await openTab(tester, 3);
      await tester.tap(find.byKey(const Key('panchang_tab_daily')));
      await tester.pumpAndSettle();
      expectSideBySide(
        tester,
        'panchang_daily_leading_pane',
        'panchang_daily_trailing_pane',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings keeps a readable width', (tester) async {
      await launch(tester, innerLandscape);
      await openTab(tester, 4);
      final card = box(tester, 'settings_premium');
      expect(card.width, lessThanOrEqualTo(720));
      expect(card.center.dx, moreOrLessEquals(951 / 2, epsilon: 2));
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => count++),
    child: SizedBox(height: 40, child: Text('$count')),
  );
}
