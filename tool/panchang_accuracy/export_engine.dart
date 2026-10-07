// Exports Panchang engine output for the accuracy harness.
//
// Usage:
//   dart run tool/panchang_accuracy/export_engine.dart <cities.json> <start> <days> <out.json>
//
// <cities.json> is a list of {id, label, lat, lon, tz}. Dates are civil dates
// in each city's IANA timezone. Instants are ISO-8601 UTC strings. The Python
// comparator (compare.py) computes independent references; nothing here is
// used by the app at runtime.
import 'dart:convert';
import 'dart:io';

import '../../lib/services/panchang/calculated_ekadashi.dart';
import '../../lib/services/panchang/panchang_city.dart';
import '../../lib/services/panchang/panchang_engine.dart';
import '../../lib/services/panchang/panchang_models.dart';

String? _iso(DateTime? value) => value?.toUtc().toIso8601String();

Map<String, Object?> _limb(PanchangLimb limb) => {
  'index': limb.index,
  'name': limb.name,
  'end': _iso(limb.endsAtUtc),
};

void main(List<String> args) {
  if (args.length != 4) {
    stderr.writeln('usage: export_engine.dart cities.json start days out.json');
    exit(64);
  }
  final cities = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final start = DateTime.parse(args[1]);
  final first = DateTime.utc(start.year, start.month, start.day);
  final count = int.parse(args[2]);
  const engine = PanchangEngine();
  const ekadashi = CalculatedEkadashiEngine();
  final output = <String, Object?>{};
  for (final row in cities) {
    final city = PanchangCity(
      id: row['id'] as String,
      label: row['label'] as String,
      latitude: (row['lat'] as num).toDouble(),
      longitude: (row['lon'] as num).toDouble(),
      timeZoneId: row['tz'] as String,
    );
    final days = <Map<String, Object?>>[];
    for (var i = 0; i < count; i++) {
      final date = first.add(Duration(days: i));
      final day = engine.calculate(date, city: city);
      days.add({
        'date': date.toIso8601String().substring(0, 10),
        'sunrise': _iso(day.sunriseUtc),
        'sunset': _iso(day.sunsetUtc),
        'moonrise': _iso(day.moonriseUtc),
        'moonset': _iso(day.moonsetUtc),
        'nextSunrise': _iso(day.nextSunriseUtc),
        'tithi': _limb(day.tithi),
        'nakshatra': _limb(day.nakshatra),
        'yoga': _limb(day.yoga),
        'karana': _limb(day.karana),
        'amanta': day.amantaMonth,
        'purnimanta': day.purnimantaMonth,
        'adhika': day.isAdhikaMonth,
        'sunRashi': day.sunRashi,
        'moonRashi': day.moonRashi,
        'rahukala': _iso(day.rahukala?.startUtc),
        'observances': [
          for (final event in day.observances)
            {'id': event.id, 'name': event.name},
        ],
      });
    }
    final fasts = <String, Object?>{};
    for (final tradition in EkadashiTradition.values) {
      // The engine accepts at most 366 civil days per request.
      final found = [
        for (var offset = 0; offset < count; offset += 366)
          ...ekadashi.calculate(
            first.add(Duration(days: offset)),
            count - offset < 366 ? count - offset : 366,
            city,
            tradition,
          ),
      ];
      fasts[tradition.name] = [
        for (final fast in found)
          {
            'date': fast.date.toIso8601String().substring(0, 10),
            'name': fast.name,
            'rule': fast.rule,
            'paranaDate': fast.paranaDate.toIso8601String().substring(0, 10),
            'paranaStart': _iso(fast.paranaStartUtc),
            'paranaEnd': _iso(fast.paranaEndUtc),
          },
      ];
    }
    output[city.id] = {'days': days, 'ekadashi': fasts};
    stderr.writeln('exported ${city.id}');
  }
  File(args[3]).writeAsStringSync(jsonEncode(output));
}
