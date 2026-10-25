import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:clock/clock.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/app_harness.dart';

void main() {
  test('Glass Look uses the shared Apple-style overlapping glass shapes', () {
    expect(AppIcons.all['glass_look'], CupertinoIcons.square_on_circle);
  });
  for (final code in AppLanguage.codes) {
    for (final dark in [true, false]) {
      for (final layout in [(393.0, 1.0), (320.0, 2.0)]) {
        testWidgets(
          'optional Glass Look retains navigation geometry and state $code dark=$dark layout=$layout',
          (tester) async {
            final harness = AppHarness();
            await tester.runAsync(
              () => harness.install(
                preferences: {
                  'language_code': code,
                  'is_dark_mode': dark,
                  'ekadashi_year': 2026,
                },
              ),
            );
            addTearDown(harness.uninstall);
            tester.view.physicalSize = Size(layout.$1, 844);
            tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            addTearDown(tester.view.reset);
            await withClock(
              Clock.fixed(DateTime.utc(2026, 10, 22, 7, 15)),
              () async {
                await tester.pumpWidget(
                  RepaintBoundary(
                    key: const Key('glass_frame'),
                    child: harness.app(),
                  ),
                );
                await tester.pumpAndSettle();
                List<Rect> tabs() => List.generate(
                  5,
                  (i) => tester.getRect(find.byKey(Key('glass_tab_$i'))),
                );
                Future<List<int>> pixels() async =>
                    (await tester.runAsync(() async {
                      final image = await tester
                          .renderObject<RenderRepaintBoundary>(
                            find.byKey(const Key('glass_frame')),
                          )
                          .toImage();
                      final data = await image.toByteData(
                        format: ui.ImageByteFormat.rawRgba,
                      );
                      image.dispose();
                      return data!.buffer.asUint8List();
                    }))!;
                final original = code == 'en' ? await pixels() : <int>[];
                final before = tabs();
                await tester.tap(find.byKey(const Key('glass_tab_1')));
                await tester.pumpAndSettle();
                tester
                    .state<CalendarScreenState>(find.byType(CalendarScreen))
                    .selectDate(DateTime(2026, 10, 20));
                await tester.pumpAndSettle();
                await tester.tap(find.byKey(const Key('glass_tab_4')));
                await tester.pumpAndSettle();
                final toggle = find.byKey(const Key('settings_glass_look'));
                await tester.scrollUntilVisible(
                  toggle,
                  120,
                  scrollable: find
                      .descendant(
                        of: find.byType(ListView).hitTestable(),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
                await tester.pumpAndSettle();
                expect(toggle, findsOneWidget);
                expect(find.descendant(of: toggle, matching: find.byIcon(AppIcons.all['glass_look']!)), findsOneWidget);
                await Scrollable.ensureVisible(
                  tester.element(toggle),
                  alignment: .5,
                );
                await tester.pumpAndSettle();
                final off = tester.widget<SwitchListTile>(
                  find.descendant(
                    of: toggle,
                    matching: find.byType(SwitchListTile),
                  ),
                );
                expect(off.value, isFalse);
                await tester.tap(
                  find.descendant(of: toggle, matching: find.byType(Switch)),
                );
                await tester.pumpAndSettle();
                expect(tabs(), before);
                await tester.tap(find.byKey(const Key('glass_tab_1')));
                await tester.pumpAndSettle();
                expect(
                  find.descendant(
                    of: find.byKey(const Key('calendar_year_selector')),
                    matching: find.text(
                      AppStrings.fullDate(DateTime(2026, 10, 20), code),
                    ),
                  ),
                  findsOneWidget,
                );
                await tester.tap(find.byKey(const Key('glass_tab_0')));
                await tester.pumpAndSettle();
                expect(tabs(), before);
                if (code == 'en') {
                  expect(listEquals(original, await pixels()), isFalse);
                }
                final details = find.byKey(const Key('view_details'));
                expect(details.hitTestable(), findsOneWidget);
                expect(
                  tester.getRect(details).bottom,
                  lessThan(
                    tester
                        .getRect(find.byKey(const Key('glass_navigation_bar')))
                        .top,
                  ),
                );
                await tester.tap(find.byKey(const Key('glass_tab_4')));
                await tester.pumpAndSettle();
                await Scrollable.ensureVisible(
                  tester.element(toggle),
                  alignment: .5,
                );
                await tester.pumpAndSettle();
                await tester.tap(
                  find.descendant(of: toggle, matching: find.byType(Switch)),
                );
                await tester.pumpAndSettle();
                expect(tabs(), before);
                await tester.tap(find.byKey(const Key('glass_tab_0')));
                await tester.pumpAndSettle();
                if (code == 'en') {
                  expect(
                    listEquals(original, await pixels()),
                    isTrue,
                    reason: 'Off must restore the exact original Home pixels',
                  );
                }
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox());
              },
            );
          },
          variant: TargetPlatformVariant.only(TargetPlatform.android),
        );
      }
    }
  }
}
