// Offline candidate export for independent reference comparison.
// Usage: dart run tool/panchang_audit.dart [year] [output.json]
import 'dart:convert';
import 'dart:io';
import '../lib/services/panchang/calculated_ekadashi.dart';
import '../lib/services/panchang/panchang_city.dart';

void main(List<String> args) {
  final year = args.isEmpty ? 2026 : int.parse(args[0]);
  final count = DateTime.utc(year + 1).difference(DateTime.utc(year)).inDays;
  final result = <String, Object>{};
  for (final city in [
    PanchangCity.newDelhi,
    PanchangCity.newYork,
    PanchangCity.london,
    PanchangCity.sydney,
  ]) {
    final profiles = <String, Object>{};
    for (final tradition in EkadashiTradition.values) {
      final days = const CalculatedEkadashiEngine().calculate(
        DateTime.utc(year),
        count,
        city,
        tradition,
      );
      profiles[tradition.name] = [
        for (final day in days)
          {
            'date': day.date.toIso8601String().substring(0, 10),
            'name': day.name,
            'rule': day.rule,
            'paranaStartUtc': day.paranaStartUtc?.toIso8601String(),
            'paranaEndUtc': day.paranaEndUtc?.toIso8601String(),
            'nearBoundary': day.nearBoundary,
          },
      ];
    }
    result[city.id] = profiles;
  }
  final output = const JsonEncoder.withIndent('  ').convert({
    'year': year,
    'ruleVersion': CalculatedEkadashi.ruleVersion,
    'locations': result,
  });
  if (args.length > 1) {
    File(args[1]).writeAsStringSync(output);
  } else {
    stdout.writeln(output);
  }
}
