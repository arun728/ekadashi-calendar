import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/widgets/glass_tube.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/section_pager.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared iOS components (ios-native DesignSystem: Glass.swift,
/// Toast.swift, Theme.swift) used by every Android screen.
void main() {
  const teal = Color(0xFF00A19B);

  Widget app(Widget child, {Brightness brightness = Brightness.dark}) =>
      MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        home: Scaffold(body: Center(child: child)),
      );

  TextStyle styleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  group('IosColors', () {
    testWidgets('system colours follow light and dark like SwiftUI', (
      tester,
    ) async {
      late BuildContext dark, light;
      await tester.pumpWidget(app(Builder(builder: (c) => const SizedBox())));
      dark = tester.element(find.byType(SizedBox));
      expect(IosColors.green(dark), const Color(0xFF30D158));
      expect(IosColors.orange(dark), const Color(0xFFFF9F0A));
      expect(IosColors.primary(dark), Colors.white);
      await tester.pumpWidget(
        app(const SizedBox(), brightness: Brightness.light),
      );
      // The theme change animates.
      await tester.pumpAndSettle();
      light = tester.element(find.byType(SizedBox));
      expect(IosColors.green(light), const Color(0xFF34C759));
      expect(IosColors.orange(light), const Color(0xFFFF9500));
      expect(IosColors.primary(light), Colors.black);
      expect(IosColors.amber, const Color(0xFFFFC208));
      expect(IosColors.missed, const Color(0xFFF0544F));
      expect(IosColors.partial, const Color(0xFFFFA100));
    });
  });

  group('GlassChip', () {
    testWidgets('selected: its own colour, 15 pt semibold, no checkmark', (
      tester,
    ) async {
      var taps = 0;
      const google = Color(0xFF4285F4);
      await tester.pumpWidget(
        app(
          GlassChip(
            label: 'Google',
            icon: Icons.event,
            color: google,
            selected: true,
            onTap: () => taps++,
          ),
        ),
      );
      final style = styleOf(tester, 'Google');
      expect(style.color, google);
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w600);
      expect(tester.widget<Icon>(find.byIcon(Icons.event)).color, google);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byType(GlassPanel), findsOneWidget);
      await tester.tap(find.text('Google'));
      expect(taps, 1);
    });

    testWidgets('unselected: primary text, regular weight', (tester) async {
      await tester.pumpWidget(
        app(GlassChip(label: 'All', selected: false, onTap: () {})),
      );
      final style = styleOf(tester, 'All');
      expect(style.color, Colors.white);
      expect(style.fontWeight, FontWeight.w400);
    });
  });

  testWidgets('StatusPill: 12 pt semibold, 12% fill, 35% border', (
    tester,
  ) async {
    await tester.pumpWidget(app(const StatusPill(text: 'IST', color: teal)));
    final style = styleOf(tester, 'IST');
    expect(style.fontSize, 12);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, teal);
    final box =
        tester
                .widget<Container>(
                  find.ancestor(
                    of: find.text('IST'),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(box.color, teal.withValues(alpha: .12));
    expect(box.border!.top.color, teal.withValues(alpha: .35));
  });

  test('prominent button: teal capsule with white text', () {
    final style = IosButtons.prominent();
    expect(style.shape!.resolve({}), isA<StadiumBorder>());
    expect(style.backgroundColor!.resolve({}), teal);
    expect(style.foregroundColor!.resolve({}), Colors.white);
    expect(IosButtons.label.fontSize, 17);
    expect(IosButtons.label.fontWeight, FontWeight.w600);
  });

  testWidgets('SheetBar: Cancel, the inline title and a bold action', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SheetBar(
          title: 'Add entry',
          leading: BarTextButton(label: 'Cancel', onPressed: () {}),
          trailing: BarTextButton(label: 'Save', bold: true, onPressed: () {}),
        ),
      ),
    );
    expect(styleOf(tester, 'Add entry').fontSize, 17);
    expect(styleOf(tester, 'Add entry').fontWeight, FontWeight.w600);
    expect(styleOf(tester, 'Save').fontWeight, FontWeight.w600);
    expect(styleOf(tester, 'Cancel').fontWeight, FontWeight.w400);
  });

  group('showToast', () {
    testWidgets('a glass toast that leaves after four seconds', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      showToast(tester.element(find.byType(SizedBox)), 'Saved');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app_toast')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('its teal action runs and closes it', (tester) async {
      var upgraded = 0;
      await tester.pumpWidget(app(const SizedBox()));
      showToast(
        tester.element(find.byType(SizedBox)),
        'Free sync used',
        actionLabel: 'Upgrade',
        onAction: () => upgraded++,
      );
      await tester.pumpAndSettle();
      expect(styleOf(tester, 'Upgrade').color, teal);
      await tester.tap(find.text('Upgrade'));
      await tester.pumpAndSettle();
      expect(upgraded, 1);
      expect(find.text('Free sync used'), findsNothing);
    });

    testWidgets('a new toast replaces the one showing', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      showToast(context, 'First');
      await tester.pumpAndSettle();
      showToast(context, 'Second');
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('showAppSheet', () {
    testWidgets('opens from the root navigator, over a nested one', (
      tester,
    ) async {
      final nested = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Navigator(
            key: nested,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showAppSheet<void>(
                    context,
                    builder: (_) => const Text('sheet'),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('sheet'),
          matching: find.byType(BottomSheet),
        ),
        findsOneWidget,
      );
      // The nested navigator still has only its first page.
      expect(nested.currentState!.canPop(), isFalse);
    });

    testWidgets('nested: pages pushed inside stay in the sheet', (
      tester,
    ) async {
      await tester.pumpWidget(app(const SizedBox()));
      showAppSheet<void>(
        tester.element(find.byType(SizedBox)),
        nested: true,
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const Text('inside'))),
          child: const Text('push'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.text('inside'),
          matching: find.byType(BottomSheet),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a medium sheet shows the grabber', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      showAppSheet<void>(
        tester.element(find.byType(SizedBox)),
        large: false,
        builder: (_) => const Text('medium'),
      );
      await tester.pumpAndSettle();
      final grabber = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 36 &&
              w.constraints?.maxHeight == 5,
        ),
      );
      expect(grabber, findsOneWidget);
    });
  });

  testWidgets('UnavailableView: symbol, bold title and description', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const UnavailableView(
          icon: Icons.search,
          title: 'No results',
          description: 'Try another year',
        ),
      ),
    );
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(styleOf(tester, 'No results').fontWeight, FontWeight.w700);
    expect(styleOf(tester, 'Try another year').fontSize, 15);
  });

  testWidgets('SectionChipBar: separate glass chips, no shared tube', (
    tester,
  ) async {
    var picked = -1;
    await tester.pumpWidget(
      app(
        SectionChipBar(
          labels: const ['Key days', 'Daily'],
          chipKeys: const [Key('a'), Key('b')],
          selected: 0,
          onSelected: (i) => picked = i,
        ),
      ),
    );
    expect(find.byType(GlassChip), findsNWidgets(2));
    expect(find.byType(GlassTube), findsNothing);
    expect(tester.widget<GlassChip>(find.byKey(const Key('a'))).selected, true);
    await tester.tap(find.byKey(const Key('b')));
    expect(picked, 1);
  });

  testWidgets('TabBarSlots: builders reach the bar after the frame', (
    tester,
  ) async {
    final slots = TabBarSlots();
    var notified = 0;
    slots.addListener(() => notified++);
    await tester.pumpWidget(app(const SizedBox()));
    slots.attach(
      leading: (_) => const Text('Today'),
      actions: (_) => [const Icon(Icons.add)],
    );
    expect(notified, 0);
    await tester.pump();
    expect(notified, 1);
    final context = tester.element(find.byType(SizedBox));
    expect((slots.leading(context) as Text).data, 'Today');
    expect(slots.actions(context), hasLength(1));
    slots.refresh();
    slots.refresh();
    await tester.pump();
    expect(notified, 2, reason: 'refreshes in one frame coalesce');
    slots.detach();
    await tester.pump();
    expect(slots.hasLeading, isFalse);
    expect(slots.actions(context), isEmpty);
  });
}
