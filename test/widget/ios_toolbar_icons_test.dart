import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/widgets/glass_look.dart';
import 'package:ekadashi_calendar/widgets/glass_navigation_bar.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/app_harness.dart';

// Arun's iPhone references: large magnifying glass and SF-style Google actions.
void main() {
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() => harness.uninstall());

  Future<void> open(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 393.0]) {
    testWidgets('large iOS search glyph on every tab at $width', (
      tester,
    ) async {
      await open(tester, width);
      for (var tab = 0; tab < 5; tab++) {
        await tester.tap(find.byKey(Key('glass_tab_$tab')));
        await tester.pumpAndSettle();
        final search = find.byKey(const Key('open_global_search'));
        final icon = tester.widget<Icon>(
          find.descendant(of: search, matching: find.byType(Icon)),
        );
        expect(icon.icon, AppIcons.search);
        expect(icon.size, 30);
        expect(
          find.ancestor(of: search, matching: find.byType(GlassPanel)),
          findsOneWidget,
        );
        expect(tester.getSize(search).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(search).height, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'Panchang removes notes and matches Home/Settings trailing search in both modes',
    (tester) async {
      await open(tester, 393);
      final theme = tester
          .element(find.byKey(const Key('open_global_search')))
          .read<ThemeService>();
      for (final enabled in [false, true]) {
        await theme.setGlassLook(enabled);
        await tester.pumpAndSettle();
        final frames = <Rect>[];
        for (final tab in [0, 4, 3]) {
          await tester.tap(find.byKey(Key('glass_tab_$tab')));
          await tester.pumpAndSettle();
          frames.add(
            tester.getRect(find.byKey(const Key('open_global_search'))),
          );
        }
        expect(find.byKey(const Key('panchang_notes')), findsNothing);
        expect(frames[2], frames[0]);
        expect(frames[2], frames[1]);
        await tester.tap(find.byKey(const Key('open_global_search')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('global_search_field')), findsOneWidget);
        await tester.tap(find.byKey(const Key('global_search_back')));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'Calendar keeps its Off toolbar while body follows the preference',
    (tester) async {
      await open(tester, 393);
      final theme = tester
          .element(find.byKey(const Key('open_global_search')))
          .read<ThemeService>();
      for (final enabled in [false, true]) {
        await theme.setGlassLook(enabled);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('glass_tab_1')));
        await tester.pumpAndSettle();
        expect(
          GlassLook.active(tester.element(find.byType(CalendarScreen))),
          enabled,
        );
        expect(
          GlassLook.active(
            tester.element(find.byKey(const Key('open_global_search'))),
          ),
          isFalse,
        );
        final search = tester.getRect(
          find.byKey(const Key('open_global_search')),
        );
        final add = tester.getRect(find.byKey(const Key('add_calendar_entry')));
        final google = tester.getRect(
          find.byKey(const Key('calendar_google_menu')),
        );
        expect(search.right, lessThanOrEqualTo(add.left));
        expect(add.right, lessThanOrEqualTo(google.left));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Google uses circular sync and person-minus iOS glyphs', (
    tester,
  ) async {
    await open(tester, 393);
    await tester.tap(find.byKey(const Key('glass_tab_1')));
    await tester.pumpAndSettle();
    final google = find.byKey(const Key('calendar_google_menu'));
    expect(
      find.descendant(of: google, matching: find.byIcon(AppIcons.googleMenu)),
      findsOneWidget,
    );
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('import_google_year')),
        matching: find.byIcon(AppIcons.googleSync),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('disconnect_google')),
        matching: find.byIcon(AppIcons.googleDisconnect),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected tab keeps the dark iPhone pill', (tester) async {
    await open(tester, 393);
    final bar = find.byType(GlassNavigationBar);
    final pill = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.descendant(of: bar, matching: find.byType(AnimatedAlign)),
        matching: find.byType(DecoratedBox),
      ),
    );
    final colour = (pill.decoration as BoxDecoration).color!;
    expect(colour.a, greaterThan(.9));
    expect(colour.computeLuminance(), lessThan(.02));
    final foreground = tester.widget<IconTheme>(
      find.descendant(
        of: find.byKey(const Key('glass_tab_0')),
        matching: find.byType(IconTheme),
      ),
    );
    expect(foreground.data.color, IosColors.teal);
  });
}
