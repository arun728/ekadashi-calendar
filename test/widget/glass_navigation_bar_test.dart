import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import 'package:ekadashi_calendar/widgets/glass_navigation_bar.dart';

List<BottomNavigationBarItem> items(String locale) {
  final l = lookupAppLocalizations(Locale(locale));
  return [
    BottomNavigationBarItem(icon: const Icon(Icons.home), label: l.home),
    BottomNavigationBarItem(
      icon: const Icon(Icons.calendar_month),
      label: l.calendar,
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.spa_outlined),
      activeIcon: const Icon(Icons.spa),
      label: l.vrat,
    ),
    BottomNavigationBarItem(icon: const Icon(Icons.search), label: l.search),
    BottomNavigationBarItem(
      icon: const Icon(Icons.settings),
      label: l.settings,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    double width = 393,
    double scale = 1,
    double bottom = 24,
    Brightness brightness = Brightness.dark,
    bool highContrast = false,
    bool accessible = false,
    bool reduceMotion = false,
    int selected = 0,
    ValueChanged<int>? onTap,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            padding: EdgeInsets.only(bottom: bottom),
            textScaler: TextScaler.linear(scale),
            highContrast: highContrast,
            accessibleNavigation: accessible,
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: GlassNavigationBar(
              items: items(locale),
              currentIndex: selected,
              onTap: onTap ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in ['en', 'ta', 'hi', 'te']) {
    for (final width in [320.0, 393.0, 700.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$locale glass tabs fit ${width}dp at text scale $scale', (
          tester,
        ) async {
          await open(tester, locale: locale, width: width, scale: scale);
          final capsule = tester.getRect(
            find.byKey(const Key('glass_capsule_surface')),
          );
          expect(capsule.width, lessThanOrEqualTo(600));
          expect(capsule.bottom, lessThanOrEqualTo(844 - 24 - 12));
          expect(capsule.left, closeTo(width - capsule.right, 0.5));
          for (var i = 0; i < 5; i++) {
            final tab = find.byKey(Key('glass_tab_$i'));
            expect(tab.hitTestable(), findsOneWidget);
            final rect = tester.getRect(tab);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThanOrEqualTo(capsule.left));
            expect(rect.right, lessThanOrEqualTo(capsule.right));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('$brightness selection uses brand teal on black', (
      tester,
    ) async {
      await open(tester, brightness: brightness);
      final selected = find.descendant(
        of: find.byKey(const Key('glass_tab_0')),
        matching: find.byType(IconTheme),
      );
      expect(
        tester.widget<IconTheme>(selected).data.color,
        const Color(0xFF00A19B),
      );
      final pill = find.descendant(
        of: find.byType(AnimatedAlign),
        matching: find.byType(DecoratedBox),
      );
      expect(
        (tester.widget<DecoratedBox>(pill).decoration as BoxDecoration).color,
        Colors.black,
      );
    });
  }
  testWidgets('Localized tab semantics expose selection and activation', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    try {
      var tapped = -1;
      await open(tester, locale: 'te', selected: 2, onTap: (i) => tapped = i);
      final destinations = items('te');
      for (var i = 0; i < 5; i++) {
        final node = tester.getSemantics(find.byKey(Key('glass_tab_$i')));
        expect(node.getSemanticsData().label, destinations[i].label);
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          node.getSemanticsData().flagsCollection.isSelected ==
              ui.Tristate.isTrue,
          i == 2,
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
      }
      await tester.tap(find.byKey(const Key('glass_tab_4')));
      expect(tapped, 4);
    } finally {
      handle.dispose();
    }
  });
  testWidgets('Already-selected tab still calls its existing repeat action', (
    tester,
  ) async {
    var calls = 0;
    await open(
      tester,
      onTap: (i) {
        expect(i, 0);
        calls++;
      },
    );
    await tester.tap(find.byKey(const Key('glass_tab_0')));
    await tester.tap(find.byKey(const Key('glass_tab_0')));
    expect(calls, 2);
  });
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      '$brightness glass has a clipped blur; accessibility uses an opaque fallback',
      (tester) async {
        await open(tester, brightness: brightness);
        expect(
          tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
          isTrue,
        );
        expect(
          find.ancestor(
            of: find.byType(BackdropFilter),
            matching: find.byType(ClipRRect),
          ),
          findsWidgets,
        );
        await open(tester, brightness: brightness, highContrast: true);
        expect(
          tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
          isFalse,
        );
        await open(tester, brightness: brightness, accessible: true);
        expect(
          tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Reduced motion disables the selected-pill transition', (
    tester,
  ) async {
    await open(tester, reduceMotion: true);
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
      Duration.zero,
    );
  });
}
