import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'android_home_followup_test.dart' as followup;

void main() {
  followup.main();
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android Glass Look in every language and theme without moving tabs',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      await prefs.setBool('is_dark_mode', true);
      await prefs.remove(ThemeService.glassLookKey);
      await tester.pumpWidget(const app.MyApp());
      Future<void> frames([int count = 8]) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      for (
        var i = 0;
        i < 240 &&
            find.byKey(const Key('home_page_indicator')).evaluate().isEmpty;
        i++
      ) {
        await frames(1);
      }
      expect(find.byKey(const Key('home_page_indicator')), findsOneWidget);
      final context = tester.element(find.byType(app.MainScreen));
      final language = context.read<LanguageService>(),
          theme = context.read<ThemeService>();
      expect(theme.isGlassLookEnabled, isFalse);
      await binding.convertFlutterSurfaceToImage();
      Future<void> capture(String name) async {
        await frames();
        await binding.takeScreenshot(name);
      }

      List<Rect> tabs() => List.generate(
        5,
        (i) => tester.getRect(find.byKey(Key('glass_tab_$i'))),
      );
      Future<List<Rect>> stableTabs() async {
        var previous = tabs();
        for (var i = 0; i < 30; i++) {
          await frames(3);
          final current = tabs();
          if (List.generate(
            5,
            (i) =>
                (current[i].left - previous[i].left).abs() < .01 &&
                (current[i].top - previous[i].top).abs() < .01 &&
                (current[i].width - previous[i].width).abs() < .01,
          ).every((v) => v)) {
            return current;
          }
          previous = current;
        }
        fail('Native Android tab geometry did not settle');
      }

      await frames(12);
      final geometry = await stableTabs();
      await capture('glass-home-off');
      for (final code in AppLanguage.codes) {
        await language.changeLanguage(code);
        await theme.toggleTheme(true);
        await frames(12);
        await tester.tap(find.byKey(const Key('glass_tab_1')));
        await frames();
        tester
            .state<CalendarScreenState>(find.byType(CalendarScreen))
            .selectDate(DateTime(2026, 10, 20));
        await frames();
        await tester.tap(find.byKey(const Key('glass_tab_4')));
        await frames();
        final toggle = find.byKey(const Key('settings_glass_look'));
        await Scrollable.ensureVisible(tester.element(toggle), alignment: .5);
        await frames();
        await tester.tap(
          find.descendant(of: toggle, matching: find.byType(Switch)),
        );
        await frames();
        expect(theme.isGlassLookEnabled, isTrue);
        expect(await stableTabs(), geometry);
        await capture('glass-settings-on-$code');
        await tester.tap(find.byKey(const Key('glass_tab_1')));
        await frames();
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
        await frames();
        expect(
          find.byKey(const Key('view_details')).hitTestable(),
          findsOneWidget,
        );
        expect(await stableTabs(), geometry);
        await capture('glass-home-on-dark-$code');
        await theme.toggleTheme(false);
        await frames();
        expect(await stableTabs(), geometry);
        await capture('glass-home-on-light-$code');
        await tester.tap(find.byKey(const Key('glass_tab_4')));
        await frames();
        await Scrollable.ensureVisible(tester.element(toggle), alignment: .5);
        await frames();
        await tester.tap(
          find.descendant(of: toggle, matching: find.byType(Switch)),
        );
        await frames();
        expect(theme.isGlassLookEnabled, isFalse);
        expect(await stableTabs(), geometry);
        await tester.tap(find.byKey(const Key('glass_tab_0')));
        await frames();
      }
      await language.changeLanguage('en');
      await theme.toggleTheme(true);
      await frames();
      await capture('glass-home-off-restored');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
