import 'package:clock/clock.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/widgets/home_fasting_progress.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../support/app_harness.dart';

void main() {
  for (final tradition in EkadashiTradition.values) {
    for (final language in AppLanguage.all) {
      testWidgets(
        'today ring, blocked feedback and menu order ${tradition.name} ${language.code}',
        (tester) async {
          final harness = AppHarness();
          await tester.runAsync(
            () => harness.install(
              preferences: {
                'language_code': language.code,
                EkadashiSettings.traditionKey: tradition.name,
                'vrat_tracker_enabled': true,
              },
            ),
          );
          addTearDown(harness.uninstall);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          // Both Chennai traditions fast on 22 October; fixed clock avoids
          // making the regression depend on the day this suite is executed.
          await withClock(
            Clock.fixed(DateTime.utc(2026, 10, 22, 7, 15)),
            () async {
              await tester.pumpWidget(harness.app());
              await tester.pumpAndSettle();
              final ring = find.byKey(const Key('home_fasting_progress'));
              expect(ring, findsOneWidget);
              final badge = find.text(
                AppStrings.translate('today', language.code),
              );
              expect(badge, findsOneWidget);
              expect(
                tester.getRect(ring).right,
                lessThan(tester.getRect(badge).left),
              );
              final circles = find.descendant(
                of: ring,
                matching: find.byType(CircularProgressIndicator),
              );
              expect(
                tester.widget<CircularProgressIndicator>(circles).value,
                closeTo(.72, .01),
              );
              final record = find.byKey(const Key('home_record_vrat'));
              final button = tester.widget<OutlinedButton>(record);
              expect(button.onPressed, isNotNull);
              expect(
                button.style!.backgroundColor!.resolve({}),
                IosColors.gray(tester.element(record)).withValues(alpha: .18),
              );
              await tester.tap(record);
              await tester.pumpAndSettle();
              expect(
                find.text(
                  AppStrings.translate(
                    'journey_record_after_parana',
                    language.code,
                  ),
                ),
                findsOneWidget,
              );
              await tester.pump(const Duration(seconds: 4));
              await tester.pumpAndSettle();
              expect(
                find.text(
                  AppStrings.translate(
                    'journey_record_after_parana',
                    language.code,
                  ),
                ),
                findsNothing,
              );
              await tester.tap(find.byKey(const Key('home_next')));
              await tester.pumpAndSettle();
              expect(ring, findsNothing);
              await tester.tap(record);
              await tester.pumpAndSettle();
              expect(
                find.text(
                  AppStrings.translate(
                    'journey_record_after_parana',
                    language.code,
                  ),
                ),
                findsOneWidget,
              );
              await tester.pump(const Duration(seconds: 4));
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('home_tradition_menu')));
              await tester.pumpAndSettle();
              final choices = tester
                  .widgetList<PopupMenuItem<EkadashiTradition>>(
                    find.byType(PopupMenuItem<EkadashiTradition>),
                  )
                  .map((e) => e.value)
                  .toList();
              expect(choices, [
                EkadashiTradition.gaudiya,
                EkadashiTradition.smarta,
              ]);
              final lang = tester
                  .element(find.byKey(const Key('home_options_tube')))
                  .read<LanguageService>();
              expect(lang.currentLocale.languageCode, language.code);
              expect(tester.takeException(), isNull);
              await tester.tapAt(const Offset(8, 550));
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('glass_tab_1')));
              await tester.pumpAndSettle();
              tester
                  .state<CalendarScreenState>(find.byType(CalendarScreen))
                  .selectDate(DateTime(2026, 10, 22));
              await tester.pumpAndSettle();
              final timings = tester
                  .widgetList<Text>(
                    find.descendant(
                      of: find.byKey(const Key('calendar_ekadashi_card')),
                      matching: find.byType(Text),
                    ),
                  )
                  .map((t) => t.data ?? '')
                  .where(
                    (t) => t.startsWith(
                      AppStrings.translate('break_fasting', language.code),
                    ),
                  );
              expect(timings, hasLength(1));
              if (language.code != 'en') {
                expect(
                  RegExp(r'\b(AM|PM)\b').hasMatch(timings.single),
                  isFalse,
                );
              }
              await tester.pumpWidget(const SizedBox());
            },
          );
        },
      );
    }
  }
  testWidgets(
    'ring contains 0/72/100 percent in all languages at large text sizes',
    (tester) async {
      for (final language in AppLanguage.codes) {
        for (final scale in [1.0, 2.0, 3.0]) {
          for (final fraction in [0.0, .72, 1.0]) {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Center(
                    child: HomeFastingProgress(
                      fraction: fraction,
                      language: language,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final ring = tester.getRect(find.byType(HomeFastingProgress));
            final text = tester.getRect(find.byType(Text));
            expect(
              ring.contains(text.topLeft) && ring.contains(text.bottomRight),
              isTrue,
            );
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );
  testWidgets(
    'today ring refreshes each minute and disappears at city midnight',
    (tester) async {
      final harness = AppHarness();
      await tester.runAsync(harness.install);
      addTearDown(harness.uninstall);
      var now = DateTime.utc(2026, 10, 22, 7, 15);
      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        double amount() => tester
            .widget<HomeFastingProgress>(
              find.byKey(const Key('home_fasting_progress')),
            )
            .fraction;
        final before = amount();
        now = now.add(const Duration(minutes: 1));
        await tester.pump(const Duration(minutes: 1));
        expect(amount(), lessThan(before));
        now = DateTime.utc(2026, 10, 22, 18, 30);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byKey(const Key('home_fasting_progress')), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );
}
