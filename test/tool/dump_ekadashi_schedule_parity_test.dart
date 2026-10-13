// Checks the Ekadashi schedule the iOS parity test compares against is the
// Dart one; regenerate it after a schedule, engine or rule change with:
//   UPDATE_IOS_FIXTURES=1 flutter test test/tool/dump_ekadashi_schedule_parity_test.dart
// Output: ios-native/EkadashiCore/Tests/EkadashiCoreTests/Fixtures/ekadashi_schedule_parity.json
// EkadashiCoreTests/EkadashiScheduleParityTests compares every field of the
// Swift schedule with these values.
import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Ekadashi schedule parity fixture matches the Dart schedule', () {
    PanchangCity city(
      String id,
      String label,
      double latitude,
      double longitude,
      String zone,
    ) => PanchangCity(
      id: 'geonames-$id',
      label: label,
      latitude: latitude,
      longitude: longitude,
      timeZoneId: zone,
    );
    final cities = [
      city('1264527', 'Chennai (IN)', 13.08784, 80.27847, 'Asia/Kolkata'),
      city('1261481', 'New Delhi (IN)', 28.62137, 77.2148, 'Asia/Kolkata'),
      city('1275339', 'Mumbai (IN)', 19.07283, 72.88261, 'Asia/Kolkata'),
      city(
        '5128581',
        'New York City (US)',
        40.71427,
        -74.00597,
        'America/New_York',
      ),
      city(
        '5368361',
        'Los Angeles (US)',
        34.05223,
        -118.24368,
        'America/Los_Angeles',
      ),
      city('2643743', 'London (GB)', 51.50853, -0.12574, 'Europe/London'),
      city('2147714', 'Sydney (AU)', -33.86785, 151.20732, 'Australia/Sydney'),
      city('1880252', 'Singapore (SG)', 1.28967, 103.85007, 'Asia/Singapore'),
      city('292223', 'Dubai (AE)', 25.07725, 55.30927, 'Asia/Dubai'),
      city('1283240', 'Kathmandu (NP)', 27.70169, 85.3206, 'Asia/Kathmandu'),
    ];
    List<Map<String, dynamic>> pack(int year) {
      final file = File('assets/calendar/$year.json');
      if (!file.existsSync()) return const [];
      return ((jsonDecode(file.readAsStringSync())
                  as Map<String, dynamic>)['ekadashis']
              as List)
          .cast<Map<String, dynamic>>();
    }

    final entries = <Map<String, dynamic>>[];
    for (final place in cities) {
      for (final tradition in EkadashiTradition.values) {
        for (final year in [2026, 2027, 2028]) {
          final fasts = EkadashiSchedule.calculate(
            EkadashiScheduleKey(place, tradition, year),
            pack(year),
          );
          entries.add({
            'city': {
              'id': place.id,
              'label': place.label,
              'latitude': place.latitude,
              'longitude': place.longitude,
              'timeZoneId': place.timeZoneId,
            },
            'tradition': tradition.name,
            'year': year,
            'fasts': [for (final fast in fasts) fast.toJson()],
          });
        }
      }
    }
    expect(entries, hasLength(60));
    final file = File(
      'ios-native/EkadashiCore/Tests/EkadashiCoreTests/Fixtures/ekadashi_schedule_parity.json',
    );
    final text = '${const JsonEncoder.withIndent(' ').convert(entries)}\n';
    if (Platform.environment['UPDATE_IOS_FIXTURES'] == '1') {
      file.writeAsStringSync(text);
    }
    expect(
      file.readAsStringSync(),
      text,
      reason:
          'The iOS fixture is out of date. Run: UPDATE_IOS_FIXTURES=1 '
          'flutter test test/tool/dump_ekadashi_schedule_parity_test.dart',
    );
  });
}
