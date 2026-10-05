import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/more_screen.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import '../support/premium_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('festival finder uses saved location and revokes paid access', (
    tester,
  ) async {
    await PanchangLocationStore().save(PanchangCity.newYork);
    final premium = PremiumService(
      backend: PremiumFixture(),
      startLeaseTimer: false,
    );
    addTearDown(premium.dispose);
    await premium.connect();
    await tester.pumpWidget(
      ChangeNotifierProvider<PremiumService>.value(
        value: premium,
        child: const MaterialApp(home: Scaffold(body: MoreScreen())),
      ),
    );
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
    premium.reset();
    await tester.pumpAndSettle();
    expect(find.text('Unlock full Panchang'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
