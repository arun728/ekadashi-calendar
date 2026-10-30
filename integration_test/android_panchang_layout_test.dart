import 'dart:convert';
import 'dart:isolate';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_pages.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_data_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/widgets/app_background.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import '../test/support/premium_fixture.dart';

int _oldYearMilliseconds() {
  final clock = Stopwatch()..start();
  const PanchangEngine().observanceCalendar(2026, city: PanchangCity.chennai);
  return clock.elapsedMilliseconds;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> frames(WidgetTester tester, [int count = 3]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> ready(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 240 && finder.evaluate().isEmpty; i++) {
      await frames(tester, 1);
    }
    expect(finder, findsWidgets);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await frames(tester);
    await binding.takeScreenshot(name);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'Home Details and Calendar align in every language and both Glass modes',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      await prefs.setInt('ekadashi_year', 2026);
      await withClock(Clock.fixed(DateTime.utc(2026, 10, 26)), () async {
        await tester.pumpWidget(const app.MyApp());
        final card = find.byKey(const Key('home_ekadashi_card'));
        await ready(tester, card);
        final context = tester.element(find.byType(app.MainScreen));
        final language = context.read<LanguageService>(),
            theme = context.read<ThemeService>();
        await binding.convertFlutterSurfaceToImage();
        for (final glass in [false, true]) {
          await theme.setGlassLook(glass);
          for (final code in AppLanguage.codes) {
            await language.changeLanguage(code);
            await frames(tester, 8);
            for (final state in ['next', 'passed']) {
              if (state == 'passed') {
                await tester.tap(find.byKey(const Key('home_previous')));
                await frames(tester, 5);
              }
              final badge = find.descendant(
                of: card,
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.decoration is ShapeDecoration,
                ),
              );
              expect(badge, findsOneWidget);
              expect(
                tester.getRect(badge).right,
                closeTo(tester.getRect(card).right - 20, 1),
              );
              await capture(tester, 'android-home-$state-$code-glass-$glass');
              await tester.tap(find.byKey(const Key('view_details')));
              await frames(tester, 5);
              final status = find.byKey(const Key('details_lifecycle_status'));
              await tester.ensureVisible(status);
              await frames(tester);
              final pill = find.descendant(
                of: status,
                matching: find.byType(StatusPill),
              );
              expect(
                tester.getRect(pill).right,
                closeTo(
                  tester.view.physicalSize.width /
                          tester.view.devicePixelRatio -
                      20,
                  1,
                ),
              );
              await capture(
                tester,
                'android-details-$state-$code-glass-$glass',
              );
              Navigator.of(tester.element(find.byType(DetailsScreen))).pop();
              await frames(tester, 5);
            }
            await tester.tap(find.byKey(const Key('home_next')));
            await frames(tester, 4);
            await tester.tap(find.byKey(const Key('glass_tab_1')));
            await frames(tester, 4);
            tester
                .state<CalendarScreenState>(find.byType(CalendarScreen))
                .selectDate(DateTime(2026, 10, 27));
            await tester.tap(find.byKey(const Key('calendar_filter_ekadashi')));
            await frames(tester, 4);
            final empty = find.byKey(const Key('calendar_no_ekadashi'));
            expect(tester.widget<Text>(empty).textAlign, TextAlign.center);
            expect(
              tester.getRect(empty).center.dx,
              closeTo(
                tester.view.physicalSize.width /
                    tester.view.devicePixelRatio /
                    2,
                1,
              ),
            );
            await capture(tester, 'android-calendar-empty-$code-glass-$glass');
            await tester.tap(find.byKey(const Key('glass_tab_0')));
            await frames(tester, 4);
          }
        }
      });
    },
  );

  testWidgets(
    'Panchang cold month and all five pages reuse real isolate calculations',
    (tester) async {
      final old = await Isolate.run(_oldYearMilliseconds);
      final month = DateTime.utc(2026, 10);
      final observances = ObservanceCalendarService(),
          data = PanchangDataService();
      final measured = <String, Object>{'old_year_ms': old};
      for (final pass in ['first', 'repeat']) {
        final clock = Stopwatch()..start();
        await observances.month(month, PanchangCity.chennai);
        measured['${pass}_month_ms'] = clock.elapsedMilliseconds;
        for (final page in ['daily', 'muhurta', 'rashi']) {
          clock.reset();
          await data.day(month, PanchangCity.chennai);
          measured['${pass}_${page}_ms'] = clock.elapsedMilliseconds;
        }
        for (final tradition in EkadashiTradition.values) {
          clock.reset();
          await data.fasts(month, PanchangCity.chennai, tradition);
          measured['${pass}_${tradition.name}_ms'] = clock.elapsedMilliseconds;
        }
      }
      debugPrint('ANDROID_PANCHANG_ENGINE ${jsonEncode(measured)}');
      final premium = PremiumService(
        entitlements: PremiumFixture()..premium = true,
      );
      await premium.refresh();
      final language = LanguageService();
      await language.changeLanguage('en');
      final theme = ThemeService();
      await EkadashiService().initializeData();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: premium),
            ChangeNotifierProvider.value(value: language),
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider(create: (_) => EkadashiSettings()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AppBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: PanchangScreen(initialCity: PanchangCity.chennai),
                ),
              ),
            ),
          ),
        ),
      );
      await binding.convertFlutterSurfaceToImage();
      for (final code in AppLanguage.codes) {
        await language.changeLanguage(code);
        await frames(tester, 4);
        for (final pass in ['first', 'repeat']) {
          for (final page in [
            'keydays',
            'daily',
            'muhurta',
            'ekadashi',
            'rashi',
          ]) {
            final chip = find.byKey(Key('panchang_tab_$page'));
            await tester.ensureVisible(chip);
            await frames(tester);
            final clock = Stopwatch()..start();
            await tester.tap(chip);
            await frames(tester, 3);
            final loaded = switch (page) {
              'keydays' => find.byKey(const Key('panchang_key_days')),
              'daily' => find.byKey(const Key('panchang_tithi_title')),
              'muhurta' => find.byKey(const Key('panchang_day_night')),
              'ekadashi' => find.byKey(const Key('panchang_fast_card')),
              _ => find.byType(PanchangRashiView),
            };
            await ready(tester, loaded);
            debugPrint(
              'ANDROID_PANCHANG_UI $code $page $pass ${clock.elapsedMilliseconds}ms',
            );
            expect(tester.widget<GlassChip>(chip).selected, isTrue);
            if (pass == 'first') {
              await capture(tester, 'android-panchang-$code-$page');
            }
            expect(tester.takeException(), isNull);
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      premium.dispose();
      language.dispose();
      theme.dispose();
    },
  );
}
