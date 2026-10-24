import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The iPhone Duo and foldable layouts (docs/FOLDABLES.md), rendered
/// offscreen by Flutter (not an emulator or simulator) at the Duo's inner
/// screen in portrait and landscape and its outer screen. The PNGs in
/// build/ui-screenshots/wide/ are review evidence; the assertions check the
/// panes are where the screen size says.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await cupertino.load();
    for (final entry in {
      'Roboto': ['Roboto-Regular.ttf'],
      'MaterialIcons': ['MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(
          File(
            'test/fonts/$file',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
  });

  const sizes = {
    'duo_inner_portrait': Size(669, 951),
    'duo_inner_landscape': Size(951, 669),
    'duo_outer': Size(466, 678),
  };

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: every tab renders', (tester) async {
      final harness = AppHarness();
      await tester.runAsync(
        () => harness.install(preferences: {'language_code': 'en'}),
      );
      addTearDown(harness.uninstall);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: harness.app()));
      await tester.pumpAndSettle();
      final wide = size.width >= 560;

      Future<void> capture(String screen) async {
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final directory = Directory('build/ui-screenshots/wide');
          await directory.create(recursive: true);
          await File(
            '${directory.path}/${name}_$screen.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> tab(int index) async {
        await tester.tap(find.byKey(Key('glass_tab_$index')));
        await tester.pumpAndSettle();
      }

      void expectPanes(String first, String second) {
        final a = tester.getRect(find.byKey(Key(first)));
        final b = tester.getRect(find.byKey(Key(second)));
        if (wide) {
          expect(a.right, lessThanOrEqualTo(b.left + 1), reason: name);
        } else {
          expect(a.bottom, lessThanOrEqualTo(b.top + 1), reason: name);
        }
      }

      expect(
        find.byKey(const Key('home_list_pane')),
        wide ? findsOneWidget : findsNothing,
      );
      await capture('1_home');

      await tab(1);
      expectPanes('calendar_grid_pane', 'calendar_day_pane');
      await capture('2_calendar');

      await tab(2);
      expectPanes(
        'journey_overview_metrics_pane',
        'journey_overview_record_pane',
      );
      await capture('3_journey');
      await tester.ensureVisible(
        find.byKey(const Key('journey_tab_statistics')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('journey_tab_statistics')));
      await tester.pumpAndSettle();
      await capture('4_journey_statistics');

      await tab(3);
      await capture('5_panchang_key_days');
      await tester.tap(find.byKey(const Key('panchang_tab_daily')));
      await tester.pumpAndSettle();
      expectPanes(
        'panchang_daily_leading_pane',
        'panchang_daily_trailing_pane',
      );
      await capture('6_panchang_daily');

      await tab(4);
      await capture('7_settings');
    });
  }
}
