import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import '../support/premium_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PremiumService> premiumService(bool active) async {
    final service = PremiumService(
      entitlements: PremiumFixture()..premium = active,
    );
    if (active) await service.refresh();
    return service;
  }

  Future<void> showPanchang(
    WidgetTester tester, {
    required PremiumService premium,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumService>.value(
        value: premium,
        child: MaterialApp(
          home: Scaffold(
            body: PanchangScreen(initialDate: DateTime(2026, 10, 4)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('free preview is useful and clearly marks premium detail', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);

    await showPanchang(tester, premium: premium);

    expect(find.text('Panchang'), findsOneWidget);
    expect(find.text('IST · English'), findsOneWidget);
    expect(find.byKey(const Key('panchang_tithi_title')), findsOneWidget);
    expect(find.text('Unlock full Panchang'), findsOneWidget);
    expect(find.text('Nakshatra'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium shows all five limbs and location-aware details', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);

    await showPanchang(tester, premium: premium);

    for (final title in ['Tithi', 'Nakshatra', 'Yoga', 'Karana', 'Vara']) {
      expect(find.text(title), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text('Lunar month labels'),
      280,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('panchang_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Purnimanta ·'), findsOneWidget);
    expect(find.text('Unlock full Panchang'), findsNothing);
    expect(find.text(PanchangCity.newDelhi.label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('city selector only offers supported Indian cities', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);

    await showPanchang(tester, premium: premium);
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();

    expect(find.text('Mumbai'), findsWidgets);
    expect(find.text('London'), findsNothing);
    await tester.tap(find.text('Mumbai').last);
    await tester.pumpAndSettle();
    expect(find.text('Mumbai'), findsOneWidget);
  });
}
