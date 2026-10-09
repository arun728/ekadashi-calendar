import 'package:ekadashi_calendar/screens/widgets/settings_premium_card.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
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

  Future<void> show(WidgetTester tester, PremiumService premium) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService?>.value(value: premium),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
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

  testWidgets('subscribers see their status, Manage and Change plan', (
    tester,
  ) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = true,
    );
    addTearDown(premium.dispose);
    await premium.refresh();
    await show(tester, premium);
    expect(find.text('You have Premium ✨'), findsOneWidget);
    expect(find.byKey(const Key('settings_premium_manage')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Change plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
