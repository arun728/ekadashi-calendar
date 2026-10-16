import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/screens/global_search_screen.dart';
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/screens/splash_screen.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/widgets/glass_navigation_bar.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The app shell looks and behaves like the iOS RootView (UI parity review,
/// 12 October 2026): the teal theme, the iOS top bar and tab symbols, one
/// navigation stack per tab, Search and the paywall as sheets, deep links
/// closing what is open, and no splash artwork.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const teal = Color(0xFF00A19B);

  group('theme', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final dark = theme.brightness == Brightness.dark;
      test('${theme.brightness}: teal controls, never Material purple', () {
        expect(theme.colorScheme.primary, teal);
        expect(theme.colorScheme.secondary, teal);
        expect(theme.progressIndicatorTheme.color, teal);
        expect(theme.textSelectionTheme.cursorColor, teal);
      });
      test('${theme.brightness}: iOS inline top bar', () {
        final bar = theme.appBarTheme;
        expect(bar.backgroundColor, Colors.transparent);
        expect(bar.centerTitle, isTrue);
        expect(bar.titleTextStyle?.fontSize, 17);
        expect(bar.titleTextStyle?.fontWeight, FontWeight.w600);
        expect(bar.titleTextStyle?.color, dark ? Colors.white : Colors.black);
        // The title keeps the app font (from the typography).
        expect(bar.titleTextStyle?.fontFamily, isNotNull);
        expect(bar.actionsIconTheme?.color, teal);
      });
    }

    testWidgets('an unstyled TextButton is teal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: TextButton(onPressed: () {}, child: const Text('x')),
          ),
        ),
      );
      final style = DefaultTextStyle.of(tester.element(find.text('x'))).style;
      expect(style.color, teal);
    });
  });

  testWidgets('the launch screen is a plain dark page (no artwork)', (
    tester,
  ) async {
    final harness = AppHarness();
    await tester.runAsync(harness.install);
    addTearDown(harness.uninstall);
    await tester.pumpWidget(harness.app());
    // First frame, before the data has loaded.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  group('shell', () {
    late AppHarness harness;
    setUp(() async {
      harness = AppHarness();
      await harness.install();
    });
    tearDown(() => harness.uninstall());

    Future<dynamic> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      return tester.state(find.byType(MainScreen));
    }

    testWidgets('tab bar uses the iOS symbols: calendar, leaf, sparkles', (
      tester,
    ) async {
      await open(tester);
      final items = tester
          .widget<GlassNavigationBar>(find.byType(GlassNavigationBar))
          .items;
      IconData icon(int i) => (items[i].icon as Icon).icon!;
      IconData active(int i) => (items[i].activeIcon as Icon).icon!;
      expect(icon(0), AppIcons.tabHome);
      expect(icon(1), AppIcons.tabCalendar);
      expect(icon(2), AppIcons.tabJourney);
      expect(icon(3), AppIcons.tabPanchang);
      // Panchang keeps one symbol (no outline/filled swap).
      expect(active(3), AppIcons.tabPanchang);
      expect(icon(4), AppIcons.tabSettings);
    });

    testWidgets('the top bar title is the iOS inline title', (tester) async {
      await open(tester);
      final title = find.descendant(
        of: find.byType(ShellTopBar),
        matching: find.text('Ekadashi Calendar'),
      );
      expect(title, findsOneWidget);
      final style = tester.widget<Text>(title).style!;
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, Colors.white);
    });

    testWidgets(
      'Details opens inside the Home tab: the tab bar stays, re-tapping Home '
      'goes back',
      (tester) async {
        await open(tester);
        await tester.tap(find.text('View Details').first);
        await tester.pumpAndSettle();
        expect(find.byType(DetailsScreen), findsOneWidget);
        // The tab bar stays visible and usable over the pushed page.
        expect(
          find.byKey(const Key('glass_navigation_bar')).hitTestable(),
          findsOneWidget,
        );
        // The pushed page has its own top bar (no shell search button).
        expect(find.byKey(const Key('open_global_search')), findsNothing);
        await tester.tap(find.byKey(const Key('glass_tab_0')));
        await tester.pumpAndSettle();
        expect(find.byType(DetailsScreen), findsNothing);
        expect(find.byKey(const Key('open_global_search')), findsOneWidget);
      },
    );

    testWidgets('Home keeps its card when you come back from another tab', (
      tester,
    ) async {
      await open(tester);
      final pager = find.byType(PageView).first;
      final controller = tester.widget<PageView>(pager).controller!;
      final start = controller.page!.round();
      controller.jumpToPage(start + 1);
      await tester.pumpAndSettle();
      expect(controller.page!.round(), start + 1);
      await tester.tap(find.byKey(const Key('glass_tab_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('glass_tab_0')));
      await tester.pumpAndSettle();
      expect(controller.page!.round(), start + 1);
    });

    testWidgets('Search opens as a sheet over the app', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('open_global_search')));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byType(GlobalSearchScreen),
          matching: find.byType(BottomSheet),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('global_search_back')));
      await tester.pumpAndSettle();
      expect(find.byType(GlobalSearchScreen), findsNothing);
    });

    testWidgets('the paywall opens as a sheet over the app', (tester) async {
      await open(tester);
      openPremium(tester.element(find.byType(GlassNavigationBar)));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byType(PremiumScreen),
          matching: find.byType(BottomSheet),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a deep link closes the search sheet and pushed pages, then shows its '
      'tab',
      (tester) async {
        final dynamic state = await open(tester);
        await tester.tap(find.text('View Details').first);
        await tester.pumpAndSettle();
        expect(find.byType(DetailsScreen), findsOneWidget);
        state.handleDeepLink(Uri.parse('ekadashi://dashboard'));
        await tester.pumpAndSettle();
        expect(find.byType(DetailsScreen), findsNothing);
        openPremium(tester.element(find.byType(GlassNavigationBar)));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumScreen), findsOneWidget);
        state.handleDeepLink(Uri.parse('ekadashi://settings'));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumScreen), findsNothing);
        expect(
          tester
              .widget<GlassNavigationBar>(find.byType(GlassNavigationBar))
              .currentIndex,
          4,
        );
      },
    );

    testWidgets('"‹ Search" back button shows its label after a result', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('open_global_search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'settings');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('search_result_screen:settings')));
      await tester.pumpAndSettle();
      final back = find.byKey(const Key('search_return'));
      expect(back, findsOneWidget);
      expect(
        find.descendant(of: back, matching: find.text('Search')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
