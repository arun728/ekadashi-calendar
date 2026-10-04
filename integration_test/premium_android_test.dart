import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import '../test/support/premium_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android free sync gate, four-language premium fixture layouts and free return',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      app.main();
      await tester.pump();
      for (
        var i = 0;
        i < 120 && find.byKey(const Key('glass_tab_1')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const Key('glass_tab_1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('glass_tab_1')));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('import_google_year')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PremiumScreen), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('premium_real_unconfigured_free_gate');
      await tester.pageBack();
      await tester.pump(const Duration(seconds: 1));
      final context = tester.element(find.byType(app.MainScreen));
      final lang = context.read<LanguageService>();
      final premium = context.read<PremiumService>();
      for (final locale in ['en', 'ta', 'hi', 'te']) {
        await lang.changeLanguage(locale);
        await tester.pump(const Duration(milliseconds: 200));
        final fixture = FixtureBilling(premium);
        if (!context.mounted) break;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PremiumScreen(billingOverride: fixture),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(lang.translate('premium_benefits')), findsOneWidget);
        await binding.takeScreenshot('premium_fixture_${locale}_plans');
        await tester.scrollUntilVisible(
          find.text(lang.translate('premium_continue_free')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await binding.takeScreenshot('premium_fixture_${locale}_free_exit');
        await tester.scrollUntilVisible(
          find.text(lang.translate('premium_reward_activate')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.text(lang.translate('premium_reward_activate')),
        );
        await tester.pump();
        await binding.takeScreenshot('premium_fixture_${locale}_rewards');
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 500));
        fixture.dispose();
      }
    },
  );
}
