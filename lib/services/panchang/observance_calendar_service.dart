import 'dart:isolate';
import 'panchang_calculation_cache.dart';
import 'panchang_city.dart';
import 'panchang_engine.dart';
import 'panchang_models.dart';

/// Key days loads only its month. Search/reminders retain whole-year coverage
/// and share the same bounded month cache, including in-flight work.
class ObservanceCalendarService {
  ObservanceCalendarService({
    Future<List<DatedObservance>> Function(DateTime, PanchangCity)? monthLoader,
    int capacity = 24,
  }) : _loadMonth = monthLoader ?? _calculateMonth,
       _months = PanchangCalculationCache(capacity: capacity);
  static final instance = ObservanceCalendarService();
  final Future<List<DatedObservance>> Function(DateTime, PanchangCity)
  _loadMonth;
  final PanchangCalculationCache<List<DatedObservance>> _months;
  final _years = PanchangCalculationCache<List<DatedObservance>>(capacity: 4);

  /// Widget tests run astronomy inline under their fake async clock.
  static bool calculateInline = false;
  static String _yearKey(PanchangCity city, int year) =>
      '${panchangPlaceKey(city)}|$year';
  static String _monthKey(PanchangCity city, DateTime month) =>
      '${_yearKey(city, month.year)}|${month.month}';
  List<DatedObservance>? cached(int year, PanchangCity city) =>
      _years.cached(_yearKey(city, year));
  List<DatedObservance>? cachedMonth(DateTime month, PanchangCity city) =>
      _months.cached(_monthKey(city, month)) ??
      cached(
        month.year,
        city,
      )?.where((x) => x.date.month == month.month).toList(growable: false);

  Future<List<DatedObservance>> month(DateTime month, PanchangCity city) {
    final date = DateTime.utc(month.year, month.month);
    return _months.value(_monthKey(city, date), () async {
      final year = cached(date.year, city);
      final value = year == null
          ? await _loadMonth(date, city)
          : year.where((x) => x.date.month == date.month).toList();
      return List.unmodifiable(value);
    });
  }

  Future<List<DatedObservance>> year(int year, PanchangCity city) =>
      _years.value(
        _yearKey(city, year),
        () async => List.unmodifiable([
          for (var m = 1; m <= 12; m++)
            ...await month(DateTime.utc(year, m), city),
        ]),
      );
  Future<List<DatedObservance>> years(
    Iterable<int> years,
    PanchangCity city,
  ) async => [for (final y in years) ...await year(y, city)];

  /// Seeds existing tests without calculating a whole year in fake async.
  void put(int year, PanchangCity city, List<DatedObservance> value) {
    _months.clear();
    _years.put(_yearKey(city, year), List.unmodifiable(value));
  }
}

// Top-level closures capture only transportable date/city inputs, not service
// futures, State or BuildContext. Isolates are unnecessary for cached values.
Future<List<DatedObservance>> _calculateMonth(
  DateTime month,
  PanchangCity city,
) {
  List<DatedObservance> calculate() => [
    for (var d = 1; d <= DateTime.utc(month.year, month.month + 1, 0).day; d++)
      for (final observance in const PanchangEngine().observancesOn(
        DateTime.utc(month.year, month.month, d),
        city: city,
      ))
        DatedObservance(
          date: DateTime.utc(month.year, month.month, d),
          observance: observance,
        ),
  ];
  return ObservanceCalendarService.calculateInline
      ? Future.value(calculate())
      : Isolate.run(calculate);
}
