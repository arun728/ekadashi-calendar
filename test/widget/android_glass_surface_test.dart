import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/widgets/app_background.dart';
import 'package:ekadashi_calendar/widgets/glass_look.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';

void main() {
  testWidgets(
    'Glass changes surfaces only when enabled and respects accessibility',
    (tester) async {
      for (final dark in [true, false]) {
        Future<Uint8List> pixels({
          required bool enabled,
          bool highContrast = false,
          bool accessible = false,
        }) async {
          const probe = AppBackground(
            child: SizedBox(
              width: 220,
              height: 170,
              child: GlassPanel(
                padding: EdgeInsets.all(20),
                child: Text('Clear surface'),
              ),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  highContrast: highContrast,
                  accessibleNavigation: accessible,
                ),
                child: GlassLook(
                  enabled: enabled,
                  child: const Center(
                    child: RepaintBoundary(
                      key: Key('glass_probe'),
                      child: probe,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final result = await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const Key('glass_probe')),
                )
                .toImage();
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            return data!.buffer.asUint8List();
          });
          return result!;
        }

        final off = await pixels(enabled: false);
        final on = await pixels(enabled: true);
        expect(listEquals(off, on), isFalse);
        expect(
          listEquals(
            await pixels(enabled: true, highContrast: true),
            await pixels(enabled: false, highContrast: true),
          ),
          isTrue,
        );
        expect(
          listEquals(
            await pixels(enabled: true, accessible: true),
            await pixels(enabled: false, accessible: true),
          ),
          isTrue,
        );
      }
    },
  );
}
