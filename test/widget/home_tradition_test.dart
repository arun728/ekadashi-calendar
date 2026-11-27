import 'package:ekadashi_calendar/services/display_clock.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/app_harness.dart';

/// iPhone and M52 (27 November 2026): the first switch to the other
/// tradition in a city spun 1-2 s while it was calculated. It is now
/// calculated in the background once the city has loaded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() {
    DisplayClock.setTestClock(null);
    harness.uninstall();
  });

  testWidgets('the other tradition is ready before the switch, so it never '
      'spins', (tester) async {
    DisplayClock.setTestClock(() => DateTime.utc(2026, 11, 27, 4, 30));
    // A place no other test calculates (the schedule is kept in memory).
    harness
      ..city = 'Udupi'
      ..latitude = 13.3347
      ..longitude = 74.7462;
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final settings = tester
        .element(find.byKey(const Key('home_location_name')))
        .read<EkadashiSettings>();
    expect(settings.tradition, EkadashiTradition.gaudiya);
    expect(
      EkadashiService().isScheduleCached(
        settings.city,
        EkadashiTradition.smarta,
        settings.years,
      ),
      isTrue,
      reason: 'Smarta is calculated in the background',
    );

    await tester.tap(find.byKey(const Key('home_tradition_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smarta').last);
    var spun = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byKey(const Key('home_recalculating')).evaluate().isNotEmpty) {
        spun = true;
      }
    }
    await tester.pumpAndSettle();
    expect(settings.tradition, EkadashiTradition.smarta);
    expect(spun, isFalse, reason: 'the switch spun');
    expect(tester.takeException(), isNull);
  });
}
