import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/widgets/home_fasting_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);
  EkadashiDate event({
    String start = '2026-10-22T06:00:00+05:30',
    String end = '2026-10-23T06:00:00+05:30',
  }) => EkadashiDate(
    id: 20,
    name: 'Papankusha',
    date: DateTime(2026, 10, 22),
    fastStartTime: '',
    fastBreakTime: '',
    description: '',
    fastingStartIso: start,
    paranaStartIso: end,
  );
  test('remaining fraction is clamped and only on the Home city civil day', () {
    double? value(String now, {String zone = 'Asia/Kolkata'}) =>
        HomeFastingProgress.remaining(event(), DateTime.parse(now), zone);
    expect(value('2026-10-21T20:00:00Z'), 1); // already 22 October in Chennai
    expect(value('2026-10-22T00:30:00Z'), 1);
    expect(value('2026-10-22T12:30:00Z'), .5);
    expect(
      value('2026-10-22T18:30:00Z'),
      isNull,
    ); // next civil day, even before Parana
    expect(value('2026-10-21T18:29:59Z'), isNull);
    expect(value('2026-10-22T00:30:00Z', zone: 'America/Los_Angeles'), isNull);
  });
  test(
    'invalid intervals are hidden; completed same-day intervals show zero',
    () {
      final now = DateTime.parse('2026-10-22T07:15:00Z');
      for (final item in [
        event(start: ''),
        event(end: ''),
        event(end: '2026-10-21T06:00:00+05:30'),
      ]) {
        expect(
          HomeFastingProgress.remaining(item, now, 'Asia/Kolkata'),
          isNull,
        );
      }
      expect(
        HomeFastingProgress.remaining(
          event(end: '2026-10-22T07:00:00+05:30'),
          now,
          'Asia/Kolkata',
        ),
        0,
      );
    },
  );
}
