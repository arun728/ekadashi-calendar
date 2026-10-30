import 'dart:async';
import 'dart:isolate';
import 'calculated_ekadashi.dart';
import 'observance_calendar_service.dart';
import 'panchang_calculation_cache.dart';
import 'panchang_city.dart';
import 'panchang_engine.dart';
import 'panchang_models.dart';

/// Language-independent raw calculations shared by all five Panchang pages.
class PanchangDataService {
  PanchangDataService({
    FutureOr<PanchangDay> Function(DateTime, PanchangCity)? dayLoader,
    FutureOr<List<CalculatedEkadashi>> Function(
      DateTime,
      PanchangCity,
      EkadashiTradition,
    )?
    fastLoader,
    int capacity = 24,
  }) : _dayLoader = dayLoader,
       _fastLoader = fastLoader,
       _days = PanchangCalculationCache(capacity: capacity),
       _fasts = PanchangCalculationCache(capacity: capacity);
  static final instance = PanchangDataService();
  final FutureOr<PanchangDay> Function(DateTime, PanchangCity)? _dayLoader;
  final FutureOr<List<CalculatedEkadashi>> Function(
    DateTime,
    PanchangCity,
    EkadashiTradition,
  )?
  _fastLoader;
  final PanchangCalculationCache<PanchangDay> _days;
  final PanchangCalculationCache<List<CalculatedEkadashi>> _fasts;

  Future<PanchangDay> day(
    DateTime date,
    PanchangCity city, {
    PanchangEngine engine = const PanchangEngine(),
  }) {
    final civil = DateTime.utc(date.year, date.month, date.day);
    return _days.value(
      '${panchangPlaceKey(city)}|$civil|${identityHashCode(engine)}',
      () => _dayLoader?.call(civil, city) ?? _calculateDay(civil, city, engine),
    );
  }

  Future<List<CalculatedEkadashi>> fasts(
    DateTime month,
    PanchangCity city,
    EkadashiTradition tradition,
  ) {
    final civil = DateTime.utc(month.year, month.month);
    return _fasts.value(
      '${panchangPlaceKey(city)}|$civil|${tradition.name}',
      () async => List.unmodifiable(
        await (_fastLoader?.call(civil, city, tradition) ??
            _calculateFasts(civil, city, tradition)),
      ),
    );
  }
}

Future<PanchangDay> _calculateDay(
  DateTime date,
  PanchangCity city,
  PanchangEngine engine,
) {
  PanchangDay calculate() => engine.calculate(date, city: city);
  return ObservanceCalendarService.calculateInline
      ? Future.value(calculate())
      : Isolate.run(calculate);
}

Future<List<CalculatedEkadashi>> _calculateFasts(
  DateTime month,
  PanchangCity city,
  EkadashiTradition tradition,
) {
  List<CalculatedEkadashi> calculate() =>
      const CalculatedEkadashiEngine().calculate(
        month,
        DateTime.utc(month.year, month.month + 1, 0).day,
        city,
        tradition,
      );
  return ObservanceCalendarService.calculateInline
      ? Future.value(calculate())
      : Isolate.run(calculate);
}
