import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';

void main() {
  const engine = PanchangEngine();
  test(
    'Hora follows weekday ruler, spans actual day/night, and is contiguous',
    () {
      final day = engine.calculate(DateTime.utc(2026, 10, 4));
      expect(day.hora.length, 24);
      expect(day.hora.first.name, 'Sun');
      expect(day.hora[1].name, 'Venus');
      expect(day.hora.first.startUtc, day.sunriseUtc);
      expect(day.hora[12].startUtc, day.sunsetUtc);
      expect(day.hora.last.endUtc, day.nextSunriseUtc);
      for (var i = 1; i < 24; i++) {
        expect(day.hora[i].startUtc, day.hora[i - 1].endUtc);
      }
    },
  );
  test(
    'Wednesday excludes Abhijit and includes eighth daytime Dur Muhurta',
    () {
      final day = engine.calculate(DateTime.utc(2026, 10, 7));
      expect(day.abhijit, isNull);
      final dur = day.additionalPeriods
          .where((p) => p.name == 'Dur Muhurta')
          .single;
      final duration = day.sunsetUtc!.difference(day.sunriseUtc!);
      expect(
        dur.startUtc.difference(day.sunriseUtc!).inSeconds,
        closeTo(duration.inSeconds * 7 / 15, 1),
      );
    },
  );
  test(
    '2026 intercalary Jyeshtha is identified instead of ordinary annual rules',
    () {
      final day = engine.calculate(DateTime.utc(2026, 5, 25));
      expect(day.isAdhikaMonth, isTrue);
      expect(day.amantaMonth, contains('Adhika'));
      expect(day.nakshatraPada, inInclusiveRange(1, 4));
      expect(day.ayanamsa, inInclusiveRange(24, 25));
    },
  );
  test('Sunday night follows its own Choghadiya order', () {
    final day = engine.calculate(DateTime.utc(2027, 1, 3));
    expect(day.choghadiya.skip(8).map((p) => p.name).toList(), [
      'Night · Shubh',
      'Night · Amrit',
      'Night · Chal',
      'Night · Rog',
      'Night · Kaal',
      'Night · Labh',
      'Night · Udveg',
      'Night · Shubh',
    ]);
    expect(day.lagna, isNotEmpty);
    expect(day.lagna.first.startUtc, day.sunriseUtc);
    expect(day.lagna.last.endUtc, day.nextSunriseUtc);
  });

  test('Adhika month keeps the same name in both month conventions', () {
    final day = engine.calculate(DateTime.utc(2026, 6, 11));
    expect(day.amantaMonth, 'Adhika Jyeshtha');
    expect(day.purnimantaMonth, 'Adhika Jyeshtha');
  });
}
