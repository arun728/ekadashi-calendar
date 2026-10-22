import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/widgets/home_fasting_progress.dart';

void main() {
  testWidgets('the entire ring paints inside its allocated bounds', (
    tester,
  ) async {
    const probe = RepaintBoundary(
      key: Key('ring_ink'),
      child: ColoredBox(
        color: Colors.black,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: HomeFastingProgress(fraction: 1, language: 'en'),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Center(child: probe),
      ),
    );
    await tester.pumpAndSettle();
    final leaked = await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('ring_ink')),
          )
          .toImage(pixelRatio: 2);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var outside = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (x >= 8 && x < image.width - 8 && y >= 8 && y < image.height - 8) {
            continue;
          }
          final i = (y * image.width + x) * 4;
          if (pixels[i] + pixels[i + 1] + pixels[i + 2] > 15) {
            outside++;
          }
        }
      }
      image.dispose();
      return outside;
    });
    expect(
      leaked,
      0,
      reason:
          'Painting outside the ring is clipped by the Home card scroll viewport',
    );
  });
}
