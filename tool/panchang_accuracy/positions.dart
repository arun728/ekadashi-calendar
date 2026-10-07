// Prints engine longitudes for instants read from stdin (ISO-8601 UTC).
// Used by check_positions.py to compare against Swiss Ephemeris.
import 'dart:convert';
import 'dart:io';
import '../../lib/services/panchang/astronomy_calculator.dart';

void main() {
  final out = <List<double>>[];
  for (final line in File(
    Platform.environment['POSITIONS_IN']!,
  ).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final t = DateTime.parse(line.trim());
    out.add([
      AstronomyCalculator.sunLongitude(t),
      AstronomyCalculator.moonLongitude(t),
      AstronomyCalculator.apparentLahiriAyanamsa(t),
    ]);
  }
  stdout.write(jsonEncode(out));
}
