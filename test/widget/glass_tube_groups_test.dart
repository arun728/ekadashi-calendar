import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['en', 'ta', 'hi', 'te']) {
    for (final variant in [
      (true, 393.0, 1.0),
      (false, 393.0, 1.0),
      (true, 320.0, 2.0),
    ]) {
      final (dark, width, scale) = variant;
      testWidgets(
        '$locale grouped tubes across five tabs, dark=$dark width=$width scale=$scale',
        (tester) async {
          final harness = AppHarness();
          await tester.runAsync(
            () => harness.install(
              preferences: {
                'language_code': locale,
                'is_dark_mode': dark,
                'vrat_tracker_enabled': true,
              },
            ),
          );
          addTearDown(harness.uninstall);
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(harness.app());
          await tester.pumpAndSettle();
          final lang = tester
              .element(find.byType(MaterialApp))
              .read<LanguageService>();
          expect(find.byKey(const Key('home_options_tube')), findsOneWidget);
          await tester.tap(find.byKey(const Key('glass_tab_1')));
          await tester.pumpAndSettle();
          for (final key in [
            'calendar_actions_tube',
            'calendar_filters_tube',
            'calendar_month_tube',
          ]) {
            expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
          }
          await tester.tap(find.byKey(const Key('glass_tab_3')));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const Key('panchang_daily_overview')),
            200,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('panchang_scroll_view')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            find.byKey(const Key('panchang_daily_overview')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('open_global_search')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('search_categories_tube')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('search_filters_tube')), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'nirjla');
          await tester.pump(const Duration(milliseconds: 450));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('search_results')), findsOneWidget);
          expect(
            tester.getSize(find.byKey(const Key('search_filters_tube'))).height,
            greaterThanOrEqualTo(48),
          );
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('glass_tab_2')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('vrat_tabs_tube')), findsOneWidget);
          await tester.tap(find.text(lang.translate('history')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('vrat_history_filters_tube')),
            findsOneWidget,
          );
          await tester.tap(find.byType(Card).first);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('vrat_record_status_tube')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('vrat_fasting_method_tube')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('glass_tab_4')));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const Key('settings_notifications_tube')),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          expect(
            find.byKey(const Key('settings_notifications_tube')),
            findsOneWidget,
          );
          // Lazy settings rows may be below the viewport.
          await tester.scrollUntilVisible(
            find.byKey(const Key('settings_about_tube')),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).hitTestable(),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.byKey(const Key('settings_about_tube')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
