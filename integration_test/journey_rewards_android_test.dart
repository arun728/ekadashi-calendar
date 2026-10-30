import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
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
      for (final method in ['oneMeal', 'other']) {
        expect(
          tester
              .widget<GlassChip>(find.byKey(Key('vrat_method_$method')))
              .onTap,
          isNull,
        );
      }
      await capture('04_record_observance');
      await tap('vrat_record_save');
      await ready(find.byKey(const Key('journey_celebration_close')));
      await capture('10_badge_unlocked');
      await tap('journey_celebration_close');
      await tap('journey_row_ekadashi:2026:02');
      await tap('vrat_status_partial');
      expect(
        tester
            .widget<GlassChip>(find.byKey(const Key('vrat_method_oneMeal')))
            .selected,
        true,
      );
      for (final method in ['fullFast', 'waterOnly', 'fruitsMilk', 'other']) {
        expect(
          tester
              .widget<GlassChip>(find.byKey(Key('vrat_method_$method')))
              .onTap,
          isNull,
        );
      }
      await capture('04b_partial_methods');
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
      expect(
        tracker.getRecordByUid('ekadashi:2026:02')!.fastingMethod,
        FastingMethod.oneMeal,
      );
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
      await tap('journey_achievements_year');
      await tester.tap(find.text('2027').last);
      await tester.pumpAndSettle();
      await tap('journey_badge_filter_annual');
      expect(
        find.byKey(const Key('journey_badge_journey_2027_q1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('journey_badge_journey_2026_q1')),
        findsNothing,
      );
      await capture('08b_annual_badges');
      await tap('journey_achievements_year');
      await tester.tap(find.text('All years').last);
      await tester.pumpAndSettle();
      await capture('08c_all_years');
      await tap('journey_tab_statistics');
      expect(find.text('Year:'), findsNothing);
      expect(find.text('1 of 49 Ekadashis'), findsOneWidget);
      await capture('05b_statistics_all_years');
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
      final theme = context.read<ThemeService>();
      expect(theme.isGlassLookEnabled, false);
      await theme.setGlassLook(true);
      await tester.pumpAndSettle();
      await tap('glass_tab_2');
      await scrollTo(find.byKey(const Key('journey_overview_year')));
      await capture('glass_on_overview_2027');
      await tap('journey_tab_history');
      await tap('journey_history_year_menu');
      await tester.tap(find.text('2026').last);
      await tester.pumpAndSettle();
      await capture('glass_on_history_2026');
      await tap('journey_row_ekadashi:2026:02');
      expect(
        tester
            .widget<GlassChip>(find.byKey(const Key('vrat_method_oneMeal')))
            .selected,
        true,
      );
      expect(
        tester
            .widget<GlassChip>(find.byKey(const Key('vrat_method_fullFast')))
            .onTap,
        isNull,
      );
      await capture('glass_on_partial_methods');
      await tap('vrat_record_cancel');
      await tap('journey_tab_achievements');
      await tap('journey_achievements_year');
      await tester.tap(find.text('2027').last);
      await tester.pumpAndSettle();
      await tap('journey_badge_filter_annual');
      expect(
        find.byKey(const Key('journey_badge_journey_2027_q1')),
        findsOneWidget,
      );
      await capture('glass_on_annual_badges_2027');
      expect(theme.isGlassLookEnabled, true);
      await tap('journey_tab_history');
      await tap('journey_history_year_menu');
      await tester.tap(find.text('2026').last);
      await tester.pumpAndSettle();
      await tap('journey_row_ekadashi:2026:03');
      await tap('vrat_status_observed');
      await tap('vrat_record_save');
      await tap('journey_tab_overview');
      expect(find.text('Current consistency streak · 3'), findsOneWidget);
      await capture('consistency_mixed_three');
      await tap('journey_tab_history');
      await tap('journey_row_ekadashi:2026:02');
      await tap('vrat_status_observed');
      await tap('vrat_record_save');
      await tester.pump(const Duration(seconds: 1));
      if (find
          .byKey(const Key('journey_celebration_close'))
          .evaluate()
          .isNotEmpty) {
        await tap('journey_celebration_close');
      }
      expect(
        tracker.userAchievements['consistent_observance']!.isUnlocked,
        true,
      );
      await tap('journey_tab_overview');
      expect(find.text('Current consistency streak · 3'), findsOneWidget);
      expect(find.text('300'), findsWidgets);
      await capture('consistency_fully_observed_three');
      await tap('journey_tab_statistics');
      expect(find.text('2026 Full-observance completion'), findsOneWidget);
      await capture('consistency_statistics_three');
      await tap('journey_tab_history');
      await tap('journey_row_ekadashi:2026:02');
      await tap('vrat_record_delete');
      await tester.tap(find.text('Delete Record').last);
      await tester.pumpAndSettle();
      expect(
        tracker.userAchievements['consistent_observance']!.isUnlocked,
        false,
      );
      await tap('journey_tab_overview');
      expect(find.text('Current consistency streak · 1'), findsOneWidget);
      await capture('consistency_after_middle_deletion');
      await tap('journey_tab_achievements');
      await tap('journey_badge_filter_consistency');
      await tap('journey_badge_consistent_observance');
      expect(find.text('Locked'), findsWidgets);
      await capture('consistency_badge_relocked');
      final restored = VratTrackerService();
      await restored.init();
      expect(restored.recordedEntryCount, 2);
      expect(
        restored.userAchievements['consistent_observance']!.isUnlocked,
        false,
      );
      await tester.tap(find.text('Got it').first);
      await tester.pumpAndSettle();
      await tap('journey_tab_history');
      for (final uid in ['01', '03']) {
        await tap('journey_row_ekadashi:2026:$uid');
        await tap('vrat_record_delete');
        await tester.tap(find.text('Delete Record').last);
        await tester.pumpAndSettle();
      }
      expect(tracker.recordedEntryCount, 0);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 2400));
      await tester.pumpAndSettle();
      await tap('journey_row_ekadashi:2026:01');
      await tap('vrat_record_save');
      await ready(find.byKey(const Key('journey_celebration_close')));
      expect(find.text('First Step'), findsWidgets);
      await capture('badge_reearned_after_delete_all');
      await tap('journey_celebration_close');
    },
  );
}
