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
      // A bottom message or the glass bar sliding in can cover the button
      // for a moment (the 12 Oct 2026 CI tap "would not hit test"), so wait
      // for movement to settle and tap again if the paywall did not open.
      for (
        var attempt = 0;
        attempt < 3 && find.byType(PremiumScreen).evaluate().isEmpty;
        attempt++
      ) {
        await Scrollable.ensureVisible(
          tester.element(unlock),
          alignment: 0.15 + 0.1 * attempt,
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(unlock, warnIfMissed: false);
        for (
          var i = 0;
          i < 10 && find.byType(PremiumScreen).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 500));
        }
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

  // Arun (16 Nov 2026), on the emulator: every corner of a plan box selects
  // it, and a tapped plan stays selected while Play refreshes report the
  // subscription in steps (it briefly has no plan).
  testWidgets('Android plan boxes answer at their corners and keep a tap', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final lang = LanguageService();
    await lang.changeLanguage('en');
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned({PremiumService.subscriptionId});
    final billing = FixtureBilling(premium);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: lang),
          ChangeNotifierProvider.value(value: premium),
        ],
        child: MaterialApp(home: PremiumScreen(billingOverride: billing)),
      ),
    );
    await tester.pumpAndSettle();
    billing.currentPlanId = 'yearly';
    billing.notifyListeners();
    await tester.pumpAndSettle();
    String cta() => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('premium_buy')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join();
    const prices = {'monthly': '₹99', 'lifetime': '₹999'};
    for (final id in prices.keys) {
      final box = tester.getRect(find.byKey(Key('premium_plan_$id')));
      for (final point in [
        box.topLeft + const Offset(3, 3),
        box.topRight + const Offset(-3, 3),
        box.bottomLeft + const Offset(3, -3),
        box.bottomRight + const Offset(-3, -3),
      ]) {
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(cta(), contains(prices[id]!), reason: '$id at $point');
      }
    }
    for (final plan in [null, 'yearly', null, 'yearly']) {
      billing.currentPlanId = plan;
      billing.notifyListeners();
      await tester.pumpAndSettle();
      expect(cta(), contains('₹999'), reason: 'Lifetime kept after $plan');
    }
    await binding.convertFlutterSurfaceToImage().timeout(
      const Duration(seconds: 15),
    );
    await tester.pump();
    await capturePremiumScreenshot(tester, binding, 'premium_tap_kept');
    billing.dispose();
    premium.dispose();
  });
}
