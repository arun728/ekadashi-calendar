import 'dart:async';

import 'package:ekadashi_calendar/services/display_clock.dart';
import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Android launch (24 November 2026): the first v2 launch calculated every
/// Ekadashi for Chennai behind "Locating…" and then again for the place the
/// phone already knew. Home now starts from that last fix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;
  setUp(() async {
    harness = AppHarness();
    await harness.install();
  });
  tearDown(() {
    DisplayClock.setTestClock(null);
    EkadashiSchedule.beforeCalculatingYear = null;
    harness.uninstall();
  });

  testWidgets('a first launch with a last fix calculates only that place', (
    tester,
  ) async {
    harness
      ..gpsAvailable = false
      ..cachedLocation = {
        'success': true,
        'city': 'Mumbai',
        'timezone': 'IST',
        'latitude': 19.0760,
        'longitude': 72.8777,
      };
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('home_location_name'))).data,
      'Mumbai (IN)',
    );
    expect(find.byKey(const Key('home_page_indicator')), findsOneWidget);
    expect(
      EkadashiService().isScheduleCached(
        EkadashiSettings.defaultCity,
        EkadashiTradition.gaudiya,
        const [2026, 2027],
      ),
      isFalse,
      reason: 'Chennai was calculated before the known place',
    );
    expect(tester.takeException(), isNull);
  });

  // M52 launch timing (27 November 2026): a fresh install calculated
  // Chennai behind the permission prompts, then the detected place 13 km
  // away, so the card dimmed and Parana moved by a minute.
  testWidgets('a first launch without a saved city or last fix waits for '
      'the detected place and calculates only it', (tester) async {
    await harness.install(preferences: {'has_launched': false});
    harness
      ..latitude = 13.0129
      ..longitude = 80.1615;
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('home_location_name'))).data,
      'Chennai (IN)',
    );
    expect(
      EkadashiService().isScheduleCached(
        EkadashiSettings.defaultCity,
        EkadashiTradition.gaudiya,
        const [2026, 2027],
      ),
      isFalse,
      reason: 'the default Chennai point was calculated before the fix',
    );
    expect(tester.takeException(), isNull);
  });

  // M52 launch timing (27 November 2026): every launch showed January's
  // passed Shattila Ekadashi for about 0.25 s before December's Utpanna.
  testWidgets('Home opens on the next Ekadashi without first showing the '
      'year\'s first one', (tester) async {
    DisplayClock.setTestClock(() => DateTime.utc(2026, 11, 27, 4, 30));
    await tester.pumpWidget(harness.app());
    var sawFirstOfYear = false;
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Shattila Ekadashi').evaluate().isNotEmpty) {
        sawFirstOfYear = true;
      }
    }
    await tester.pumpAndSettle();
    expect(find.text('Utpanna Ekadashi'), findsWidgets);
    expect(sawFirstOfYear, isFalse, reason: 'the passed card flashed first');
    expect(tester.takeException(), isNull);
  });

  // M52 first launch (27 November 2026): after the location tap Home showed
  // "Locating…" for about 2.3 s while every Ekadashi of 2026 and 2027 was
  // calculated. The next weeks alone give the first card at once.
  testWidgets('a new place shows the next Ekadashi before its full years are '
      'calculated, then the full list', (tester) async {
    DisplayClock.setTestClock(() => DateTime.utc(2026, 11, 27, 4, 30));
    await harness.install(preferences: {'has_launched': false});
    // A place no other test calculates (the schedule is kept in memory).
    harness
      ..city = 'Bengaluru'
      ..latitude = 12.9716
      ..longitude = 77.5946;
    final fullYears = Completer<void>();
    EkadashiSchedule.beforeCalculatingYear = () => fullYears.future;
    await tester.pumpWidget(harness.app());
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Utpanna Ekadashi'), findsWidgets);
    expect(
      find.byKey(const Key('home_page_indicator')),
      findsNothing,
      reason: 'the count of the year is not known yet',
    );
    expect(find.byKey(const Key('home_recalculating')), findsNothing);

    // M52, declined location (27 November 2026): when the full list
    // replaced the first card, January's Shattila showed for one frame.
    fullYears.complete();
    var sawFirstOfYear = false;
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Shattila Ekadashi').evaluate().isNotEmpty) {
        sawFirstOfYear = true;
      }
    }
    await tester.pumpAndSettle();
    expect(sawFirstOfYear, isFalse, reason: 'the passed card flashed');
    expect(find.text('Utpanna Ekadashi'), findsWidgets);
    expect(find.byKey(const Key('home_page_indicator')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // M52, 27 November 2026: Don't allow on the location prompt.
  testWidgets('declining location on a fresh install shows Chennai\'s next '
      'Ekadashi, without another card first', (tester) async {
    DisplayClock.setTestClock(() => DateTime.utc(2026, 11, 27, 4, 30));
    await harness.install(preferences: {'has_launched': false});
    harness.locationGranted = false;
    await tester.pumpWidget(harness.app());
    var sawFirstOfYear = false;
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Shattila Ekadashi').evaluate().isNotEmpty) {
        sawFirstOfYear = true;
      }
    }
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('home_location_name'))).data,
      'Chennai (IN)',
    );
    expect(find.text('Utpanna Ekadashi'), findsWidgets);
    expect(sawFirstOfYear, isFalse);
    expect(tester.takeException(), isNull);
  });
}
