// Exports Flutter engine results for the iOS parity test:
//   flutter test test/tool/dump_panchang_parity_test.dart
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
  test('dump Panchang parity fixture for iOS', () {
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
    )..createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent(' ').convert({'days': days, 'fasts': fasts})}\n',
    );
    expect(days, hasLength(cities.length * 14));
  });
}
