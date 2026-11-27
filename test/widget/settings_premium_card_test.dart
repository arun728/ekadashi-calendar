import 'package:ekadashi_calendar/screens/widgets/settings_premium_card.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/premium_fixture.dart';

/// Phase 5 (docs/ROADMAP.md): a clear Premium card at the top of Settings.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(
    WidgetTester tester,
    PremiumService premium, {
    PlayBillingService? billing,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService?>.value(value: premium),
          ChangeNotifierProvider<PlayBillingService?>.value(value: billing),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: MaterialApp(
          theme: theme ?? ThemeData.dark(),
          home: const Scaffold(body: SettingsPremiumCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('free users see what Premium unlocks and See plans', (
    tester,
  ) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
    addTearDown(premium.dispose);
    await show(tester, premium);
    expect(find.text('Ekadashi Premium'), findsOneWidget);
    expect(find.text('Everything for your Ekadashi journey'), findsOneWidget);
    expect(find.textContaining('Google Calendar sync'), findsOneWidget);
    expect(find.textContaining('Full Panchang'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'See plans'), findsOneWidget);
    expect(find.byKey(const Key('settings_premium_manage')), findsNothing);
  });

  // Arun (27 Nov 2026): Manage moved to the Purchases section, so the card
  // keeps one main action and notes point to Manage subscription below.
  testWidgets('subscribers see their status and only Change plan', (
    tester,
  ) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = true,
    );
    addTearDown(premium.dispose);
    await premium.refresh();
    await show(tester, premium);
    expect(find.text('You have Premium ✨'), findsOneWidget);
    expect(find.byKey(const Key('settings_premium_manage')), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Change plan'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled subscription points to Manage subscription below', (
    tester,
  ) async {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned(
        {PremiumService.subscriptionId},
        autoRenewing: {PremiumService.subscriptionId: false},
      );
    addTearDown(premium.dispose);
    await show(tester, premium);
    expect(
      find.text(
        'Premium stays on until the end of the period you paid for. '
        'See the date in Google Play. '
        'Reactivate it in Manage subscription below.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Change plan'), findsOneWidget);
    expect(find.byKey(const Key('settings_premium_manage')), findsNothing);
  });

  const note =
      'Your subscription is still active. '
      'Cancel it in Manage subscription below.';

  testWidgets('Lifetime only: the thank-you message and no buttons', (
    tester,
  ) async {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned({PremiumService.lifetimeId});
    addTearDown(premium.dispose);
    await show(tester, premium);
    expect(find.text(note), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('Lifetime with a renewing subscription: a note, no buttons', (
    tester,
  ) async {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned(
        {PremiumService.lifetimeId, PremiumService.subscriptionId},
        autoRenewing: {PremiumService.subscriptionId: true},
      );
    addTearDown(premium.dispose);
    await show(tester, premium);
    expect(find.text(note), findsOneWidget);
    expect(find.byKey(const Key('settings_premium_manage')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('Lifetime with a cancelled subscription: no note', (
    tester,
  ) async {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned(
        {PremiumService.lifetimeId, PremiumService.subscriptionId},
        autoRenewing: {PremiumService.subscriptionId: false},
      );
    addTearDown(premium.dispose);
    await show(tester, premium);
    expect(find.text(note), findsNothing);
  });

  testWidgets('a cancelled switch leaves out "Reactivate anytime"', (
    tester,
  ) async {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned(
        {PremiumService.subscriptionId},
        autoRenewing: {PremiumService.subscriptionId: false},
      );
    addTearDown(premium.dispose);
    final billing = FixtureBilling(premium)..switchCancelledByPlay = true;
    addTearDown(billing.dispose);
    await show(tester, premium, billing: billing);
    expect(find.textContaining('Reactivate anytime'), findsNothing);
    expect(
      find.text(
        'Premium stays on until the end of the period you paid for. '
        'See the date in Google Play.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a scheduled Monthly switch shows the same line as iOS, with no date',
    (tester) async {
      final premium = PremiumService(
        entitlements: PremiumFixture()..premium = true,
      );
      addTearDown(premium.dispose);
      await premium.refresh();
      final billing = FixtureBilling(premium)..monthlySwitchScheduled = true;
      addTearDown(billing.dispose);
      await show(tester, premium, billing: billing);
      expect(
        find.text(
          'Switching to Monthly at renewal. See the renewal date in Google Play.',
        ),
        findsOneWidget,
      );
      expect(find.text('Switch plans or go lifetime anytime.'), findsNothing);
    },
  );
}
