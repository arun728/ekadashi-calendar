import 'package:clock/clock.dart';
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
      testWidgets('today ring, blocked feedback and menu order ${tradition.name} ${language.code}', (tester) async {
        final harness = AppHarness();
        await tester.runAsync(() => harness.install(preferences: {
          'language_code': language.code,
          EkadashiSettings.traditionKey: tradition.name,
          'vrat_tracker_enabled': true,
        }));
        addTearDown(harness.uninstall);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // Both Chennai traditions fast on 22 October; fixed clock avoids
        // making the regression depend on the day this suite is executed.
        await withClock(Clock.fixed(DateTime.utc(2026, 10, 22, 7, 15)), () async {
          await tester.pumpWidget(harness.app());
          await tester.pumpAndSettle();
          final ring = find.byKey(const Key('home_fasting_progress'));
          expect(ring, findsOneWidget);
          final badge = find.text(AppStrings.translate('today', language.code));
          expect(badge, findsOneWidget);
          expect(tester.getRect(ring).right, lessThan(tester.getRect(badge).left));
          final circles = find.descendant(of: ring, matching: find.byType(CircularProgressIndicator));
          expect(tester.widget<CircularProgressIndicator>(circles).value, closeTo(.72, .01));
          final record = find.byKey(const Key('home_record_vrat'));
          final button = tester.widget<OutlinedButton>(record);
          expect(button.onPressed, isNotNull);
          expect(button.style!.backgroundColor!.resolve({}), IosColors.gray(tester.element(record)).withValues(alpha: .18));
          await tester.tap(record);
          await tester.pumpAndSettle();
          expect(find.text(AppStrings.translate('journey_record_after_parana', language.code)), findsOneWidget);
          await tester.tap(find.byKey(const Key('home_next')));
          await tester.pumpAndSettle();
          expect(ring, findsNothing);
          await tester.tap(record);
          await tester.pumpAndSettle();
          expect(find.text(AppStrings.translate('journey_record_after_parana', language.code)), findsOneWidget);
          await tester.tap(find.byKey(const Key('home_tradition_menu')));
          await tester.pumpAndSettle();
          final choices = tester.widgetList<PopupMenuItem<EkadashiTradition>>(find.byType(PopupMenuItem<EkadashiTradition>)).map((e) => e.value).toList();
          expect(choices, [EkadashiTradition.gaudiya, EkadashiTradition.smarta]);
          final lang = tester.element(find.byKey(const Key('home_options_tube'))).read<LanguageService>();
          expect(lang.currentLocale.languageCode, language.code);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      });
    }
  }
}
