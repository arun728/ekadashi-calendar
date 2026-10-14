import 'package:ekadashi_calendar/screens/settings_screen.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets(
    'Previously opened tabs keep dates and sections after all language switches',
    (tester) async {
      final harness = AppHarness();
      await tester.runAsync(harness.install);
      addTearDown(harness.uninstall);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      Future<void> tab(int index) async {
        await tester.tap(find.byKey(Key('glass_tab_$index')));
        await tester.pumpAndSettle();
      }

      final day = DateTime(2027, 9, 14);
      await tab(1);
      tester
          .state<CalendarScreenState>(find.byType(CalendarScreen))
          .selectDate(day);
      await tester.pumpAndSettle();
      await tab(2);
      await tester.tap(find.byKey(const Key('journey_tab_history')));
      await tester.pumpAndSettle();
      await tab(3);
      tester
          .state<PanchangScreenState>(find.byType(PanchangScreen))
          .showDate(day);
      await tester.pumpAndSettle();
      await tab(4);
      for (final language in [
        ...AppLanguage.all.skip(1),
        AppLanguage.all.first,
      ]) {
        await tab(0);
        await tester.tap(find.byKey(const Key('language_menu')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(PopupMenuItem<String>, language.nativeName),
        );
        await tester.pumpAndSettle();
        await tab(1);
        expect(
          find.text(AppStrings.fullDate(day, language.code)).hitTestable(),
          findsOneWidget,
        );
        await tab(2);
        expect(
          tester
              .widget<GlassChip>(find.byKey(const Key('journey_tab_history')))
              .selected,
          isTrue,
        );
        await tab(3);
        expect(
          tester
              .widget<GlassChip>(find.byKey(const Key('panchang_tab_daily')))
              .selected,
          isTrue,
        );
        expect(
          find.text(AppStrings.fullDate(day, language.code)).hitTestable(),
          findsWidgets,
        );
        await tab(4);
        // Below the fold on a short screen: scroll to it.
        final settingsList = find
            .descendant(
              of: find.descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(ListView),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        tester.state<ScrollableState>(settingsList).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text(AppStrings.translate('appearance', language.code)),
          200,
          scrollable: settingsList,
        );
        await tester.pumpAndSettle();
        expect(
          find
              .text(AppStrings.translate('appearance', language.code))
              .hitTestable(),
          findsOneWidget,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Reusing tabs in ${language.code}',
        );
      }
    },
  );
  for (final tab in [0, 1]) {
    testWidgets(
      'Opening the ${tab == 0 ? 'language' : 'Google'} menu keeps the tab toolbar and layout',
      (tester) async {
        final harness = AppHarness();
        await tester.runAsync(harness.install);
        addTearDown(harness.uninstall);
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('glass_tab_$tab')));
        await tester.pumpAndSettle();
        final anchor = find.byKey(
          Key(tab == 0 ? 'home_options_tube' : 'calendar_month_tube'),
        );
        final position = tester.getTopLeft(anchor);
        await tester.tap(
          find.byKey(Key(tab == 0 ? 'language_menu' : 'calendar_google_menu')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ShellTopBar), findsOneWidget);
        expect(
          tester.getTopLeft(anchor),
          position,
          reason: 'An overlay menu must not move the page beneath it',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ShellTopBar), findsOneWidget);
        expect(tester.getTopLeft(anchor), position);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (width, scale) in [(393.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'Home language switches preserve the selected fast at ${width}px and ${scale}x text',
      (tester) async {
        final harness = AppHarness();
        await tester.runAsync(harness.install);
        addTearDown(harness.uninstall);
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(harness.app());
        await tester.pumpAndSettle();
        final pager = find.byType(PageView).first;
        final controller = tester.widget<PageView>(pager).controller!;
        controller.jumpToPage(4);
        await tester.pumpAndSettle();
        for (final language in [
          ...AppLanguage.all.skip(1),
          AppLanguage.all.first,
        ]) {
          await tester.tap(find.byKey(const Key('language_menu')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(PopupMenuItem<String>, language.nativeName),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Switch to ${language.code}',
          );
          final service = tester
              .element(find.byKey(const Key('language_menu')))
              .read<LanguageService>();
          expect(service.currentLocale.languageCode, language.code);
          expect(
            controller.page!.round(),
            4,
            reason: 'Language changes must keep the selected occurrence',
          );
          final expected = EkadashiService().getEkadashis(
            timezone: 'IST',
            languageCode: language.code,
          )[4];
          // Large text scrolls inside the card while its actions stay pinned.
          await tester.ensureVisible(find.text(expected.name));
          await tester.pumpAndSettle();
          expect(find.text(expected.name).hitTestable(), findsOneWidget);
          expect(find.byType(PopupMenuItem<String>), findsNothing);
          await tester.tap(find.byKey(const Key('view_details')).hitTestable());
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DetailsScreen>(find.byType(DetailsScreen))
                .ekadashi
                .occurrenceUid,
            expected.occurrenceUid,
          );
          expect(find.text(expected.name), findsWidgets);
          await tester.tap(find.byKey(const Key('glass_tab_0')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('glass_tab_4')));
          await tester.pumpAndSettle();
          expect(
            find.text(service.translate('settings')).hitTestable(),
            findsWidgets,
          );
          await tester.tap(find.byKey(const Key('glass_tab_0')));
          await tester.pumpAndSettle();
          expect(controller.page!.round(), 4);
        }
      },
    );
  }
}
