import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import '../support/premium_fixture.dart';

/// PR #12's More tab (festival finder and guides) lives inside Panchang so
/// the app keeps five bottom tabs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> showPanchang(WidgetTester tester, PremiumService premium) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumService>.value(
        value: premium,
        child: MaterialApp(
          home: Scaffold(
            body: PanchangScreen(initialDate: DateTime.utc(2026, 10, 4)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSubtab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(Tab, label));
    await tester.pumpAndSettle();
  }

  testWidgets('Guide subtab is free and explains the calculation rules', (
    tester,
  ) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
    addTearDown(premium.dispose);
    await showPanchang(tester, premium);

    await openSubtab(tester, 'Guide');

    expect(find.text('Panchang guide'), findsOneWidget);
    expect(find.text('Smarta and Vaishnava'), findsOneWidget);
    expect(find.text('Sources and coverage'), findsOneWidget);
    expect(find.text('Unlock full Panchang'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Festivals subtab shows the paywall card to free users', (
    tester,
  ) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
    addTearDown(premium.dispose);
    await showPanchang(tester, premium);

    await openSubtab(tester, 'Festivals');

    expect(find.text('Festival finder'), findsNothing);
    expect(find.text('Unlock full Panchang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'festival finder uses the saved location and closes when Play revokes premium',
    (tester) async {
      await PanchangLocationStore().save(PanchangCity.newYork);
      final play = PremiumFixture();
      final premium = PremiumService(entitlements: play);
      addTearDown(premium.dispose);
      await premium.refresh();
      await showPanchang(tester, premium);

      await openSubtab(tester, 'Festivals');
      await tester.tap(find.text('Festival finder'));
      await tester.pump(const Duration(milliseconds: 350));
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('New York · America/New_York'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no-matching-festival');
      await tester.pumpAndSettle();
      expect(
        find.text('No matching calculated observances this month.'),
        findsOneWidget,
      );

      // Google Play no longer reports the purchase (subscription ended).
      play.premium = false;
      await tester.runAsync(premium.refresh);
      await tester.pumpAndSettle();
      expect(find.text('Unlock full Panchang'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
