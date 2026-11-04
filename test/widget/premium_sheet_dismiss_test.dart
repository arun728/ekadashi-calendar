import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/widgets/glass_look.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/premium_fixture.dart';

class _UnavailableBilling extends FixtureBilling {
  _UnavailableBilling(super.premium);

  @override
  Future<void> initialize() async {
    plans.clear();
    notifyListeners();
  }
}

// A live screenshot frame can take longer than Tooltip's long-press deadline.
// Model that delay at the first frame pumped by the synthetic fling.
class _SlowGestureFrameBinding extends AutomatedTestWidgetsFlutterBinding {
  bool delayNextGestureFrame = false;

  @override
  Future<void> pump([
    Duration? duration,
    EnginePhase newPhase = EnginePhase.sendSemanticsUpdate,
  ]) {
    if (delayNextGestureFrame) {
      delayNextGestureFrame = false;
      return super.pump(
        (duration ?? Duration.zero) + const Duration(milliseconds: 600),
        newPhase,
      );
    }
    return super.pump(duration, newPhase);
  }
}

void main() {
  final binding = _SlowGestureFrameBinding();
  for (final slowFrame in [false, true]) {
    for (final storeReady in [false, true]) {
      for (final glass in [false, true]) {
        testWidgets(
          'Premium sheet dismisses from its close control: glass=$glass store=$storeReady slowFrame=$slowFrame',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = const Size(411, 731);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final language = LanguageService();
            final premium = PremiumService(entitlements: PremiumFixture());
            final billing = storeReady
                ? FixtureBilling(premium)
                : _UnavailableBilling(premium);
            final look = ValueNotifier(false);
            addTearDown(look.dispose);
            addTearDown(language.dispose);
            addTearDown(premium.dispose);
            addTearDown(billing.dispose);
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: language),
                  ChangeNotifierProvider.value(value: premium),
                ],
                child: ValueListenableBuilder<bool>(
                  valueListenable: look,
                  builder: (_, enabled, child) =>
                      GlassLook(enabled: enabled, child: child!),
                  child: MaterialApp(
                    theme: AppTheme.darkTheme,
                    home: Builder(
                      builder: (context) => Scaffold(
                        body: TextButton(
                          onPressed: () => showAppSheet<void>(
                            context,
                            builder: (_) =>
                                PremiumScreen(billingOverride: billing),
                          ),
                          child: const Text('Open Premium'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            for (final enabled in glass ? [false, true] : [false]) {
              look.value = enabled;
              await tester.pumpAndSettle();
              await tester.tap(find.text('Open Premium'));
              await tester.pumpAndSettle();
              expect(find.byType(PremiumScreen), findsOneWidget);
              expect(
                find.byKey(const Key('premium_plan_monthly')),
                storeReady ? findsOneWidget : findsNothing,
              );
              expect(
                find.byType(ClearGlassSurface),
                enabled ? findsWidgets : findsNothing,
              );
              binding.delayNextGestureFrame = slowFrame;
              await tester.fling(
                find.byKey(const Key('premium_close')),
                const Offset(0, 650),
                1200,
              );
              for (var frame = 0; frame < 8; frame++) {
                await tester.pump(const Duration(milliseconds: 200));
              }
              expect(find.byType(PremiumScreen), findsNothing);
              expect(find.text('Open Premium'), findsOneWidget);
            }
          },
        );
      }
    }
  }
}
