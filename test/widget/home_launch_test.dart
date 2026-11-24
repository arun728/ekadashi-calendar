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
  tearDown(() => harness.uninstall());

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
}
