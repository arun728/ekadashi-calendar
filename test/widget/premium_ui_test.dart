import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import '../support/premium_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Roboto': ['EkadashiTestFont.ttf'],
      'MaterialIcons': ['MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(
          File('test/fonts/$file').readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
  });
  for (final locale in ['en', 'ta', 'hi', 'te', 'gu', 'bn']) {
    for (final variant in [
      (1.0, Brightness.dark),
      (2.0, Brightness.dark),
      (1.0, Brightness.light),
      (2.0, Brightness.light),
    ]) {
      final (scale, brightness) = variant;
      testWidgets(
        '$locale ${brightness.name} transparent plans, free exit and narrow ${scale}x layout',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final lang = LanguageService();
          await lang.changeLanguage(locale);
          final backend = PremiumFixture()..premium = false;
          final premium = PremiumService(entitlements: backend);
          final store = FixtureBilling(premium);
          addTearDown(premium.dispose);
          addTearDown(store.dispose);
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final key = GlobalKey();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: lang),
                ChangeNotifierProvider.value(value: premium),
              ],
              child: MaterialApp(
                theme: brightness == Brightness.dark
                    ? AppTheme.darkTheme
                    : AppTheme.lightTheme,
                home: RepaintBoundary(
                  key: key,
                  child: PremiumScreen(billingOverride: store),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(lang.translate('premium_feature_calendar')),
            findsOneWidget,
          );
          Future<void> capture(String suffix) async {
            expect(tester.takeException(), isNull);
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final dir = Directory('build/ui-screenshots/offscreen/premium');
              await dir.create(recursive: true);
              await File(
                '${dir.path}/${locale}_${scale}_${brightness.name}_$suffix.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('plans');
          // One call to action and a compact footer; closing is the X.
          final buy = find.byKey(const Key('premium_buy'));
          expect(buy, findsOneWidget);
          expect(find.text(lang.translate('premium_manage')), findsOneWidget);
          expect(
            find.text(lang.translate('premium_continue_free')),
            findsNothing,
          );
          // Rewards are hidden for v2; the paywall must not show them.
          expect(
            find.text(lang.translate('premium_reward_activate')),
            findsNothing,
          );
          expect(find.text(lang.translate('premium_wallet')), findsNothing);
          final label = find.descendant(of: buy, matching: find.byType(Text));
          final buttonRect = tester.getRect(buy);
          final labelRect = tester.getRect(label);
          expect(
            labelRect.top - buttonRect.top,
            greaterThanOrEqualTo(8),
            reason: 'Translated labels need vertical space inside the button',
          );
          expect(buttonRect.bottom - labelRect.bottom, greaterThanOrEqualTo(8));
          await capture('free_exit');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
