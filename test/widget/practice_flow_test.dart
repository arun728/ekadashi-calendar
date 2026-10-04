import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/practice_screen.dart';
import 'package:ekadashi_calendar/services/practice_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import '../support/premium_fixture.dart';

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 100,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).hitTestable().last,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['en', 'ta', 'hi', 'te']) {
    for (final paid in [false, true]) {
      testWidgets(
        '$locale practice saves routine and recovers chanting, premium=$paid',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final language = LanguageService();
          await language.changeLanguage(locale);
          final fixture = PremiumFixture()..premium = paid;
          final premium = PremiumService(
            backend: fixture,
            startLeaseTimer: false,
          );
          await premium.connect();
          final practice = PracticeService(premium: () => premium.isPremium);
          await practice.initialize();
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: language),
                ChangeNotifierProvider.value(value: premium),
                ChangeNotifierProvider.value(value: practice),
              ],
              child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: PracticeScreen(openVrat: () {}, openLibrary: (_) {}),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await reveal(tester, find.byKey(const Key('practice_add_routine')));
          await tester.tap(find.byKey(const Key('practice_add_routine')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('routine_name')),
            'My practice',
          );
          await reveal(
            tester,
            find.widgetWithText(
              CheckboxListTile,
              language.translate('practice_chant'),
            ),
          );
          await tester.tap(
            find.widgetWithText(
              CheckboxListTile,
              language.translate('practice_chant'),
            ),
          );
          await tester.pumpAndSettle();
          await reveal(tester, find.byKey(const Key('routine_save')));
          await tester.tap(find.byKey(const Key('routine_save')));
          await tester.pumpAndSettle();
          expect(practice.routines.single.title, 'My practice');
          await reveal(tester, find.byKey(const Key('practice_start')));
          await tester.tap(find.byKey(const Key('practice_start')));
          await tester.pumpAndSettle();
          await reveal(tester, find.byKey(const Key('japa_toggle')));
          await tester.tap(find.byKey(const Key('japa_toggle')));
          await tester.pumpAndSettle();
          await reveal(tester, find.byKey(const Key('japa_increment')));
          await tester.tap(find.byKey(const Key('japa_increment')));
          await tester.pumpAndSettle();
          expect(practice.count, 1);
          await reveal(
            tester,
            find.byKey(const Key('japa_count')),
            delta: -100,
          );
          expect(find.text('1'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await reveal(tester, find.byKey(const Key('practice_start')));
          await tester.tap(find.byKey(const Key('practice_start')));
          await tester.pumpAndSettle();
          expect(practice.count, 1);
          await reveal(tester, find.byKey(const Key('japa_finish')));
          await tester.tap(find.byKey(const Key('japa_finish')));
          await tester.pumpAndSettle();
          expect(practice.streak, 1);
          expect(practice.sessions, hasLength(paid ? 1 : 0));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          practice.dispose();
          premium.dispose();
          language.dispose();
        },
      );
    }
  }
}
