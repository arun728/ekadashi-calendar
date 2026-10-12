import 'package:ekadashi_calendar/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/app_harness.dart';

/// Phase 8 (docs/ROADMAP.md): the iOS teal-to-black gradient behind every
/// Android tab, with no opaque page painted over it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() => harness.uninstall());

  test('the gradient matches the iOS AppBackground', () {
    final dark = AppBackground.gradient(Brightness.dark);
    expect(dark.colors.first, AppBackground.teal.withValues(alpha: .22));
    expect(dark.colors[1], Colors.transparent);
    expect(dark.colors.last, AppBackground.teal.withValues(alpha: .08));
    expect(dark.begin, Alignment.topLeft);
    expect(dark.end, Alignment.bottomRight);
    expect(
      AppBackground.gradient(Brightness.light).colors.first,
      AppBackground.teal.withValues(alpha: .14),
    );
    expect(AppBackground.page(Brightness.dark), const Color(0xFF121212));
  });

  testWidgets('every tab shows the gradient through transparent pages', (
    tester,
  ) async {
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.byType(AppBackground), findsOneWidget);
    for (var tab = 0; tab < 5; tab++) {
      await tester.tap(find.byKey(Key('glass_tab_$tab')));
      await tester.pumpAndSettle();
      final background = tester.getRect(find.byType(AppBackground));
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(background, Offset.zero & size, reason: 'tab $tab, full screen');
      // Each Scaffold on screen lets the gradient through.
      for (final scaffold in tester.widgetList<Scaffold>(
        find.byType(Scaffold).hitTestable(),
      )) {
        expect(
          scaffold.backgroundColor,
          Colors.transparent,
          reason: 'tab $tab',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}
