import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/app_harness.dart';

void main() {
  for (final dark in [true, false]) {
    testWidgets('Glass Off preserves the pre-feature Home image dark=$dark', (tester) async {
      final harness = AppHarness();
      await tester.runAsync(() => harness.install(preferences: {'is_dark_mode': dark}));
      addTearDown(harness.uninstall);
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await withClock(Clock.fixed(DateTime.utc(2026,10,22,7,15)), () async {
        await tester.pumpWidget(RepaintBoundary(key: const Key('baseline_image'), child: harness.app()));
        await tester.pumpAndSettle();
        await expectLater(find.byKey(const Key('baseline_image')), matchesGoldenFile('goldens/android_glass_off_${dark ? 'dark' : 'light'}.png'));
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
