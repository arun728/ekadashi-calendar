import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/screens/settings_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Journey 2026/2027 full Android flow, free limits, badges, sharing and six-language UI',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      await prefs.setBool('dark_mode', true);
      app.main();
      await tester.pump();
      Future<void> ready(Finder f) async {
        for (var i = 0; i < 90 && f.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(f, findsWidgets);
      }

      Future<void> tap(String id) async {
        final f = find.byKey(Key(id));
        await ready(f);
        await tester.ensureVisible(f.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(f.first);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
      }

      Future<void> capture(String name) async {
        debugPrint('Journey screenshot: $name');
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 300));
        var done = false;
        final shot = binding.takeScreenshot('journey_$name');
        unawaited(
          shot.then<void>(
            (_) => done = true,
            onError: (Object e, StackTrace s) {
              done = true;
            },
          ),
        );
        for (var i = 0; i < 150 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await shot.timeout(const Duration(seconds: 10));
        expect(tester.takeException(), isNull);
      }

      Future<void> scrollTo(Finder f) async {
        if (f.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            f,
            300,
            scrollable: find.byType(Scrollable).last,
          );
        } else {
          await tester.ensureVisible(f.first);
        }
        await tester.pumpAndSettle();
      }

      await ready(find.byKey(const Key('glass_tab_2')));
      await tap('glass_tab_2');
      await ready(find.byKey(const Key('journey_year_points')));
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await tap('journey_tab_history');
      await tap('journey_row_ekadashi:2026:01');
      await capture('04_record_observance');
      await tap('vrat_record_save');
      await ready(find.byKey(const Key('journey_celebration_close')));
      await capture('10_badge_unlocked');
      await tap('journey_celebration_close');
      await tap('journey_row_ekadashi:2026:02');
      await tap('vrat_status_partial');
      await tap('vrat_record_save');
      await tap('journey_row_ekadashi:2026:03');
      await tap('vrat_status_missed');
      await tap('vrat_record_save');
      await capture('03_history');
      await tap('journey_row_ekadashi:2026:04');
      await tap('vrat_record_save');
      await ready(find.byKey(const Key('premium_close')));
      await capture('13_fourth_entry_premium');
      await tap('premium_close');
      await tap('vrat_record_cancel');
      final context = tester.element(find.byType(app.MainScreen));
      final tracker = context.read<VratTrackerService>();
      expect(tracker.recordedEntryCount, 3);
      expect(tracker.getRecordByUid('ekadashi:2026:04'), isNull);
      await tap('journey_tab_statistics');
      await capture('05_statistics');
      await tap('journey_tab_overview');
      await capture('01_overview_2026');
      expect(find.text('150'), findsWidgets);
      await scrollTo(find.byKey(const Key('journey_share_year')));
      await capture('02_chapters');
      await tap('journey_share_year');
      await ready(find.byKey(const Key('journey_share_confirm')));
      await capture('11_annual_share');
      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();
      await tap('journey_tab_achievements');
      await capture('06_badge_collection');
      await tap('journey_badge_first_vrat');
      await capture('09_badge_detail');
      await tester.tap(find.text('Got it').first);
      await tester.pumpAndSettle();
      await tap('journey_badge_filter_consistency');
      await capture('07_consistency');
      await tap('journey_badge_filter_encouragement');
      await capture('08_encouragement');
      await tap('journey_badge_filter_annual');
      await capture('08b_annual_badges');
      await tap('journey_tab_overview');
      await scrollTo(find.byKey(const Key('journey_overview_year')));
      await tap('journey_overview_year');
      await tester.tap(find.text('2027').last);
      await tester.pumpAndSettle();
      await capture('01b_overview_2027');
      final lang = context.read<LanguageService>();
      for (final code in ['hi', 'ta', 'te', 'gu', 'bn']) {
        await lang.changeLanguage(code);
        await tester.pumpAndSettle();
        expect(
          find.text(
            AppStrings.translateWithArgs('ios_journey_year_points', code, [
              '0',
              '4100',
            ]),
          ),
          findsOneWidget,
        );
        await capture('locale_$code');
      }
      await lang.changeLanguage('en');
      await tester.pumpAndSettle();
      await tap('glass_tab_4');
      await ready(find.byType(SettingsScreen));
      await scrollTo(find.byKey(const Key('journey_badge_haptics')));
      await capture('12_settings_haptics');
      await tap('journey_badge_haptics');
      expect(tracker.badgeHaptics, false);
      expect(prefs.getBool('journey_badge_haptics'), false);
    },
  );
}
