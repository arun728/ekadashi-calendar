import '../../lib/services/panchang/panchang_engine.dart';
import '../../lib/services/panchang/panchang_city.dart';
void main() {
  const e = PanchangEngine();
  final sw = Stopwatch()..start();
  for (var i = 0; i < 60; i++) {
    e.calculate(DateTime.utc(2026, 1, 1).add(Duration(days: i)), city: PanchangCity.newDelhi);
  }
  print('ms per day: ${sw.elapsedMilliseconds / 60}');
}
