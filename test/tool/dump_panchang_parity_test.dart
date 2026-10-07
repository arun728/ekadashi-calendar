// Checks the Flutter engine results the iOS parity test compares against
// are current (instants within one second, numbers within 1e-9); regenerate
// them after an engine or rule change with:
//   UPDATE_IOS_FIXTURES=1 flutter test test/tool/dump_panchang_parity_test.dart
// Output: ios-native/EkadashiCore/Tests/EkadashiCoreTests/Fixtures/panchang_parity.json
// EkadashiCoreTests/PanchangParityTests compares every field of the Swift
// port with these values.
import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Panchang parity fixture matches the Dart engine', () {
    const engine = PanchangEngine();
    const cities = [
      PanchangCity.newDelhi,
      PanchangCity.chennai,
      PanchangCity.london,
      PanchangCity.newYork,
      PanchangCity.sydney,
      PanchangCity(
        id: 'reykjavik',
        label: 'Reykjavik',
        latitude: 64.1466,
        longitude: -21.9426,
        timeZoneId: 'Atlantic/Reykjavik',
      ),
      PanchangCity(
        id: 'longyearbyen',
        label: 'Longyearbyen',
        latitude: 78.2232,
        longitude: 15.6267,
        timeZoneId: 'Arctic/Longyearbyen',
      ),
      PanchangCity(
        id: 'chatham',
        label: 'Chatham',
        latitude: -43.95,
        longitude: -176.55,
        timeZoneId: 'Pacific/Chatham',
      ),
    ];
    String? t(DateTime? value) => value?.toUtc().toIso8601String();
    Map<String, dynamic> limb(PanchangLimb l) => {
      'index': l.index,
      'name': l.name,
      'end': t(l.endsAtUtc),
      'paksha': l.paksha,
    };
    Map<String, dynamic>? period(PanchangPeriod? p) => p == null
        ? null
        : {'name': p.name, 'start': t(p.startUtc), 'end': t(p.endUtc)};
    final days = <Map<String, dynamic>>[];
    for (final city in cities) {
      for (var k = 0; k < 14; k++) {
        final date = DateTime.utc(2026, 1, 3).add(Duration(days: k * 131));
        final day = engine.calculate(date, city: city);
        days.add({
          'city': {
            'id': city.id,
            'label': city.label,
            'lat': city.latitude,
            'lon': city.longitude,
            'tz': city.timeZoneId,
          },
          'date': date.toIso8601String().substring(0, 10),
          'sunrise': t(day.sunriseUtc),
          'sunset': t(day.sunsetUtc),
          'moonrise': t(day.moonriseUtc),
          'moonset': t(day.moonsetUtc),
          'nextSunrise': t(day.nextSunriseUtc),
          'tithi': limb(day.tithi),
          'nakshatra': limb(day.nakshatra),
          'yoga': limb(day.yoga),
          'karana': limb(day.karana),
          'vara': day.vara,
          'amanta': day.amantaMonth,
          'purnimanta': day.purnimantaMonth,
          'adhika': day.isAdhikaMonth,
          'periods': [
            for (final p in [
              day.rahukala,
              day.yamaganda,
              day.gulika,
              day.abhijit,
              day.brahmaMuhurta,
            ])
              period(p),
          ],
          'choghadiya': [for (final p in day.choghadiya) period(p)],
          'hora': [for (final p in day.hora) period(p)],
          'additional': [for (final p in day.additionalPeriods) period(p)],
          'lagna': [for (final p in day.lagna) period(p)],
          'specialYogas': day.specialYogas,
          'pada': day.nakshatraPada,
          'ayanamsa': day.ayanamsa,
          'ritu': day.ritu,
          'ayana': day.ayana,
          'sunRashi': day.sunRashi,
          'moonRashi': day.moonRashi,
          'sunRashiEnd': t(day.sunRashiEndsAtUtc),
          'moonRashiEnd': t(day.moonRashiEndsAtUtc),
          'padaEnd': t(day.padaEndsAtUtc),
          'anandadi': day.anandadiYoga,
          'shaka': day.shakaYear,
          'vikrama': day.vikramaYear,
          'timeline': {
            for (final e in day.limbTimeline.entries)
              e.key: [for (final l in e.value) limb(l)],
          },
          'observances': [
            for (final o in day.observances)
              {
                'id': o.id,
                'name': o.name,
                'description': o.description,
                'major': o.isMajor,
              },
          ],
          'formattedSunrise': formatPanchangTime(day.sunriseUtc, city, date),
        });
      }
    }
    final fasts = <Map<String, dynamic>>[];
    for (final city in [
      PanchangCity.newDelhi,
      PanchangCity.newYork,
      PanchangCity.sydney,
    ]) {
      for (final tradition in EkadashiTradition.values) {
        for (final fast in const CalculatedEkadashiEngine().calculate(
          DateTime.utc(2028, 1, 1),
          120,
          city,
          tradition,
        )) {
          fasts.add({
            'city': city.id,
            'tradition': tradition.name,
            'date': fast.date.toIso8601String().substring(0, 10),
            'name': fast.name,
            'rule': fast.rule,
            'paranaStart': t(fast.paranaStartUtc),
            'paranaEnd': t(fast.paranaEndUtc),
            'reason': fast.paranaReason,
            'nearBoundary': fast.nearBoundary,
          });
        }
      }
    }
    final file = File(
      'ios-native/EkadashiCore/Tests/EkadashiCoreTests/Fixtures/panchang_parity.json',
    );
    final actual = {'days': days, 'fasts': fasts};
    expect(days, hasLength(cities.length * 14));
    if (Platform.environment['UPDATE_IOS_FIXTURES'] == '1') {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent(' ').convert(actual)}\n',
        );
      return;
    }
    final differences = <String>[];
    _compare(
      jsonDecode(file.readAsStringSync()),
      jsonDecode(jsonEncode(actual)),
      r'$',
      differences,
    );
    expect(
      differences.take(20).toList(),
      isEmpty,
      reason:
          'The iOS parity fixture is stale (${differences.length} '
          'differences). Run: UPDATE_IOS_FIXTURES=1 flutter test '
          'test/tool/dump_panchang_parity_test.dart, then update the Swift '
          'port until PanchangParityTests passes.',
    );
  });
}

final _instant = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}');

void _compare(Object? expected, Object? actual, String path, List<String> out) {
  if (expected is Map && actual is Map) {
    final keys = {...expected.keys, ...actual.keys};
    for (final key in keys) {
      _compare(expected[key], actual[key], '$path.$key', out);
    }
  } else if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      out.add('$path: length ${expected.length} vs ${actual.length}');
      return;
    }
    for (var i = 0; i < expected.length; i++) {
      _compare(expected[i], actual[i], '$path[$i]', out);
    }
  } else if (expected is num && actual is num) {
    if ((expected - actual).abs() > 1e-9)
      out.add('$path: $expected vs $actual');
  } else if (expected is String &&
      actual is String &&
      _instant.hasMatch(expected) &&
      _instant.hasMatch(actual)) {
    final delta = DateTime.parse(
      expected,
    ).difference(DateTime.parse(actual)).inMilliseconds.abs();
    if (delta > 1000) out.add('$path: $expected vs $actual');
  } else if (expected != actual) {
    out.add('$path: $expected vs $actual');
  }
}
