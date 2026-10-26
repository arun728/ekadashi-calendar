import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_data_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';

void main() {
  final month = DateTime.utc(2026, 10);
  const city = PanchangCity.chennai;
  test('Key days requests only one month, coalesces and reuses it for a year', () async {
    final requests = <DateTime>[];
    final pending = Completer<List<DatedObservance>>();
    final service = ObservanceCalendarService(monthLoader: (date, city) {
      requests.add(date);
      return requests.length == 1 ? pending.future : Future.value([]);
    });
    final first = service.month(month, city);
    final second = service.month(DateTime.utc(2026, 10, 26), city);
    expect(requests, [month]);
    pending.complete([]);
    await Future.wait([first, second]);
    await service.month(month, city);
    expect(requests.length, 1);
    await service.year(2026, city);
    expect(requests.length, 12);
    expect(requests.toSet().length, 12);
  });
  test('month keys include coordinates, timezone and year; eviction is bounded', () async {
    var calls = 0;
    final service = ObservanceCalendarService(capacity: 1, monthLoader: (_, _) async { calls++; return []; });
    const otherZone = PanchangCity(id: 'chennai', label: 'Chennai', latitude: 13.0827, longitude: 80.2707, timeZoneId: 'UTC');
    await service.month(month, city);
    await service.month(month, city);
    await service.month(month, otherZone);
    await service.month(month, city);
    await service.month(DateTime.utc(2027, 10), city);
    expect(calls, 4);
  });
  test('monthly engine output matches the existing year including leap day', () async {
    ObservanceCalendarService.calculateInline = true;
    final service = ObservanceCalendarService();
    final value = await service.month(DateTime.utc(2028, 2, 20), city);
    final expected = const PanchangEngine().observanceCalendar(2028, city: city).where((x) => x.date.month == 2);
    expect(value.map((x) => '${x.date}:${x.observance.id}'), expected.map((x) => '${x.date}:${x.observance.id}'));
  });
  test('Daily, Muhurta and Rashi share in-flight day work without language in the key', () async {
    final fixture = const PanchangEngine().calculate(month, city: city);
    var calls = 0;
    final pending = Completer<PanchangDay>();
    final service = PanchangDataService(dayLoader: (_, _) { calls++; return pending.future; });
    final pages = [for (var i=0;i<3;i++) service.day(month, city)];
    expect(calls, 1);
    pending.complete(fixture);
    expect(await Future.wait(pages), everyElement(same(fixture)));
    await service.day(month, city);
    expect(calls, 1);
    await service.day(month.add(const Duration(days: 1)), city);
    await service.day(month, PanchangCity.mumbai);
    expect(calls, 3);
  });
  test('both fast traditions, retries, immutable cached results and bounded eviction', () async {
    var calls = 0;
    final service = PanchangDataService(capacity: 1, fastLoader: (_, _, _) async {
      calls++;
      if(calls == 1) throw StateError('retry');
      return [];
    });
    await expectLater(service.fasts(month, city, EkadashiTradition.smarta), throwsStateError);
    final results = await Future.wait([service.fasts(month, city, EkadashiTradition.smarta), service.fasts(month, city, EkadashiTradition.smarta)]);
    expect(calls, 2);
    expect(() => results.first.clear(), throwsUnsupportedError);
    await service.fasts(month, city, EkadashiTradition.gaudiya);
    await service.fasts(month, city, EkadashiTradition.smarta);
    expect(calls, 4);
  });
  test('real isolate transport works for day, month and both fast traditions', () async {
    ObservanceCalendarService.calculateInline = false;
    addTearDown(() => ObservanceCalendarService.calculateInline = true);
    final service = PanchangDataService();
    final day = await service.day(month, city);
    expect(day.city, city);
    final observances = await ObservanceCalendarService().month(month, city);
    expect(observances, isNotEmpty);
    for(final tradition in EkadashiTradition.values) {
      final result = await service.fasts(month, city, tradition);
      expect(result, isNotEmpty);
      expect(result.map((x) => x.date), const CalculatedEkadashiEngine().calculate(month, 31, city, tradition).map((x) => x.date));
    }
  });
}
