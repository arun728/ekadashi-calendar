import 'dart:ffi' show Abi;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/app_harness.dart';

void main() {
  // Blur edges and font antialiasing differ between the host software
  // renderers. Keep exact pixel comparisons for each Linux architecture;
  // the original references are the macOS captures.
  final renderer = switch (Abi.current()) {
    Abi.linuxX64 => 'linux-x64/',
    Abi.linuxArm64 => 'linux-arm64/',
    _ => '',
  };
  for (final dark in [true, false]) {
    testWidgets(
      'Glass Off Home visual baseline with outlined actions dark=$dark',
      (tester) async {
        final harness = AppHarness();
        await tester.runAsync(
          () => harness.install(
            preferences: {'is_dark_mode': dark, 'ekadashi_year': 2026},
          ),
        );
        addTearDown(harness.uninstall);
        tester.view.physicalSize = const Size(393, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await withClock(
          Clock.fixed(DateTime.utc(2026, 10, 22, 7, 15)),
          () async {
            await tester.pumpWidget(
              RepaintBoundary(
                key: const Key('baseline_image'),
                child: harness.app(),
              ),
            );
            await tester.pumpAndSettle();
            await expectLater(
              find.byKey(const Key('baseline_image')),
              matchesGoldenFile(
                'goldens/${renderer}android_glass_off_${dark ? 'dark' : 'light'}.png',
              ),
            );
            await tester.pumpWidget(const SizedBox());
          },
        );
      },
    );
  }
}
