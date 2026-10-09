import 'dart:async';

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

// Android API 24 can stall native screenshot capture while the surface is
// static. Keep the test producing frames and fail with a named deadline
// instead of leaving the emulator job blocked until its global timeout.
Future<void> capturePremiumScreenshot(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  debugPrint('Premium screenshot start: $name');
  var complete = false;
  final capture = binding.takeScreenshot(name);
  unawaited(
    capture.then<void>(
      (_) => complete = true,
      onError: (Object error, StackTrace stack) {
        complete = true;
      },
    ),
  );
  for (var frame = 0; frame < 150 && !complete; frame++) {
    await tester
        .pump(const Duration(milliseconds: 200))
        .timeout(const Duration(seconds: 5));
  }
  await capture.timeout(
    const Duration(seconds: 5),
    onTimeout: () =>
        throw TimeoutException('Screenshot did not complete: $name'),
  );
  debugPrint('Premium screenshot complete: $name');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android Panchang premium gate, four-language paywall layouts and free return',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      app.main();
      await tester.pump();
      debugPrint('Premium Android flow: waiting for main navigation');
      for (
        var i = 0;
        i < 120 && find.byKey(const Key('glass_tab_1')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const Key('glass_tab_1')), findsOneWidget);
      debugPrint('Premium Android flow: opening Panchang');
      await tester.tap(find.byKey(const Key('glass_tab_3')));
      // Panchang is built when first opened and calculates the month's
      // festivals before Key days and its unlock card appear; slow emulators
      // (API 24) need more than a fixed delay.
      final scrollView = find.byKey(const Key('panchang_scroll_view'));
      final loading = find.descendant(
        of: scrollView,
        matching: find.byType(CircularProgressIndicator),
      );
      for (
        var i = 0;
        i < 90 &&
            (scrollView.evaluate().isEmpty || loading.evaluate().isNotEmpty);
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(scrollView, findsOneWidget);
      expect(loading, findsNothing);
      // Key days opens first; the full upgrade card is on the Daily page.
      await tester.tap(find.byKey(const Key('panchang_tab_daily')));
      for (
        var i = 0;
        i < 30 &&
            find.byKey(const Key('panchang_unlock_button')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      // The unlock card is below the fold in Panchang's lazy list.
      final unlock = find.byKey(const Key('panchang_unlock_button'));
      await tester.scrollUntilVisible(
        unlock,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('panchang_scroll_view')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // Bring it near the top: the floating glass navigation bar and bottom
      // overlays (such as a location snackbar) cannot cover the tap there.
      await Scrollable.ensureVisible(tester.element(unlock), alignment: 0.15);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(unlock);
      for (
        var i = 0;
        i < 20 && find.byType(PremiumScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(PremiumScreen), findsOneWidget);
      debugPrint('Premium Android flow: free Panchang gate opened');
      // Play-only premium: no Google sign-in and no rewards on the paywall.
      expect(find.text('Sign in securely with Google'), findsNothing);
      expect(find.text('Fasting rewards'), findsNothing);
      await binding.convertFlutterSurfaceToImage().timeout(
        const Duration(seconds: 15),
      );
      await tester.pump().timeout(const Duration(seconds: 15));
      await capturePremiumScreenshot(tester, binding, 'premium_real_free_gate');
      await tester.tap(find.byKey(const Key('premium_close')));
      await tester.pump(const Duration(seconds: 1));
      final context = tester.element(find.byType(app.MainScreen));
      final lang = context.read<LanguageService>();
      final premium = context.read<PremiumService>();
      for (final locale in ['en', 'ta', 'hi', 'te', 'gu', 'bn']) {
        debugPrint('Premium Android flow: fixture locale $locale');
        await lang.changeLanguage(locale);
        await tester.pump(const Duration(milliseconds: 200));
        final fixture = FixtureBilling(premium);
        if (!context.mounted) break;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PremiumScreen(
              key: ValueKey('premium_fixture_$locale'),
              billingOverride: fixture,
            ),
          ),
        );
        for (
          var i = 0;
          i < 30 &&
              find
                  .byKey(ValueKey('premium_fixture_$locale'))
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.byKey(ValueKey('premium_fixture_$locale')), findsOneWidget);
        final scrollable = find
            .descendant(
              of: find.byKey(ValueKey('premium_fixture_$locale')),
              matching: find.byType(Scrollable),
            )
            .first;
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        // The compact paywall lists the three premium features for a free
        // user; closing is the X (no "continue free" button).
        final feature = find.text(lang.translate('premium_feature_calendar'));
        for (var i = 0; i < 30 && feature.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await capturePremiumScreenshot(
          tester,
          binding,
          'premium_fixture_${locale}_before_validation',
        );
        expect(feature, findsOneWidget);
        expect(find.textContaining('₹99'), findsWidgets);
        expect(
          find.text(lang.translate('premium_continue_free')),
          findsNothing,
        );
        await capturePremiumScreenshot(
          tester,
          binding,
          'premium_fixture_${locale}_plans',
        );
        await tester.ensureVisible(find.text(lang.translate('premium_manage')));
        await tester.pump();
        await capturePremiumScreenshot(
          tester,
          binding,
          'premium_fixture_${locale}_free_exit',
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('premium_close')));
        await tester.pump(const Duration(milliseconds: 500));
        fixture.dispose();
      }
    },
  );
}
