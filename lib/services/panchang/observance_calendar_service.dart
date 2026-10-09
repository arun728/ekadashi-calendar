import 'dart:async';
import 'dart:isolate';

import 'panchang_city.dart';
import 'panchang_engine.dart';
import 'panchang_models.dart';

/// A year of Panchang observances at a city, calculated off the UI isolate
/// and kept for the session. Search, Key days and event reminders share it
/// (the Swift `AppModel.panchangObservances`).
class ObservanceCalendarService {
  ObservanceCalendarService._();
  static final instance = ObservanceCalendarService._();

  final _values = <String, List<DatedObservance>>{};
  final _running = <String, Future<List<DatedObservance>>>{};

  /// Calculates in the calling isolate (widget tests, where isolates do not
  /// run under fake async).
  static bool calculateInline = false;

  static String _key(PanchangCity city, int year) =>
      '${city.id}|${city.latitude}|${city.longitude}|${city.timeZoneId}|$year';

  /// The calculated year, if it is ready.
  List<DatedObservance>? cached(int year, PanchangCity city) =>
      _values[_key(city, year)];

  Future<List<DatedObservance>> year(int year, PanchangCity city) {
    final key = _key(city, year);
    // A new future each time: a finished one from another zone would only
    // deliver its value in that zone (widget tests run in fake async).
    final done = _values[key];
    if (done != null) return Future.value(done);
    return _running[key] ??= () async {
      try {
        final value = calculateInline
            ? const PanchangEngine().observanceCalendar(year, city: city)
            : await Isolate.run(
                () =>
                    const PanchangEngine().observanceCalendar(year, city: city),
              );
        _values[key] = value;
        return value;
      } finally {
        _running.remove(key);
      }
    }();
  }

  Future<List<DatedObservance>> years(
    Iterable<int> years,
    PanchangCity city,
  ) async => [for (final y in years) ...await year(y, city)];

  /// Seeds results (tests).
  void put(int year, PanchangCity city, List<DatedObservance> value) =>
      _values[_key(city, year)] = value;
}
