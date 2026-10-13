import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/app_harness.dart';

void main() {
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
  for (final width in [393.0, 320.0]) {
    testWidgets(
      'Home language switches preserve the selected fast at ${width}px',
      (tester) async {
        final harness = AppHarness();
        await tester.runAsync(harness.install);
        addTearDown(harness.uninstall);
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
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
