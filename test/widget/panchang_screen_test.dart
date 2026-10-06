import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import '../support/premium_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
    await tester.scrollUntilVisible(
      find.text('Unlock full Panchang'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('panchang_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
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
      find.text('Detailed Panchang'),
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
    await tester.drag(
      find.byKey(const Key('panchang_scroll_view')),
      const Offset(0, 1800),
    );
    await tester.pumpAndSettle();
    expect(find.text(PanchangCity.newDelhi.label), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location editor accepts coordinates and an IANA timezone', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);

    await showPanchang(tester, premium: premium);
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();

    expect(find.text('Mumbai'), findsWidgets);

    await tester.tap(find.text('Mumbai').last);
    await tester.pumpAndSettle();
    expect(find.text('Mumbai'), findsOneWidget);
  });
  testWidgets('custom location validates and displays selected timezone', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium);
    await tester.tap(find.byKey(const Key('panchang_edit_location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('location_name')), 'New York');
    await tester.enterText(find.byKey(const Key('location_latitude')), '400');
    await tester.enterText(
      find.byKey(const Key('location_longitude')),
      '-74.006',
    );
    await tester.enterText(
      find.byKey(const Key('location_timezone')),
      'America/New_York',
    );
    await tester.tap(find.text('Save location'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a latitude from -90 to 90'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('location_latitude')),
      '40.7128',
    );
    await tester.tap(find.text('Save location'));
    await tester.pumpAndSettle();
    expect(find.text('America/New_York · English'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('panchang_location'), contains('America/New_York'));
  });
  testWidgets('Panchang subtabs organize daily, muhurta, fasting and rashi', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium);
    for (final label in ['Daily', 'Muhurta', 'Ekadashi', 'Rashi']) {
      expect(find.widgetWithText(Tab, label), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(Tab, 'Muhurta'));
    await tester.pumpAndSettle();
    expect(find.text('Daily timings'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Ekadashi'));
    await tester.pump();
    expect(find.text('Smarta'), findsOneWidget);
    expect(find.text('Vaishnava · Gaudiya/ISKCON'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('premium Muhurta fits a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    await showPanchang(tester, premium: premium);
    await tester.tap(find.widgetWithText(Tab, 'Muhurta'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lunar month labels'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('panchang_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
  });
}
