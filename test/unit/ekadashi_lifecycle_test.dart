import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:ekadashi_calendar/services/ekadashi_lifecycle.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';

EkadashiDate lifecycleEvent({String end = '2026-10-23T08:21:00+05:30'}) =>
    EkadashiDate(
      id: 20,
      name: 'Ekadashi',
      date: DateTime(2026, 10, 22),
      fastStartTime: '06:00 AM',
      fastBreakTime: '06:00 AM - 08:21 AM',
      description: '',
      fastingStartIso: '2026-10-22T06:00:00+05:30',
      paranaStartIso: '2026-10-23T06:00:00+05:30',
      paranaEndIso: end,
    );
void main() {
  setUpAll(tzdata.initializeTimeZones);
  test(
    'countdown, ascending progress, overnight and Parana exact boundaries',
    () {
      final event = lifecycleEvent();
      for (final row in [
        (
          '2026-10-22T00:00:00+05:30',
          EkadashiPhase.countdown,
          null,
          '06:00:00',
        ),
        (
          '2026-10-22T05:59:59+05:30',
          EkadashiPhase.countdown,
          null,
          '00:00:01',
        ),
        ('2026-10-22T06:00:00+05:30', EkadashiPhase.fasting, 0, 'Now'),
        ('2026-10-23T00:00:00+05:30', EkadashiPhase.fasting, 75, 'Now'),
        ('2026-10-23T06:00:00+05:30', EkadashiPhase.parana, 100, 'Parana'),
        ('2026-10-23T08:21:00+05:30', EkadashiPhase.passed, null, 'Passed'),
      ]) {
        final state = EkadashiLifecycle.of(
          event,
          DateTime.parse(row.$1),
          'Asia/Kolkata',
        );
        expect(state.phase, row.$2);
        expect(state.percent, row.$3);
        expect(state.label('en'), row.$4);
      }
    },
  );
  test('Home selection and Calendar preserve Parana without another dot', () {
    final a = lifecycleEvent(),
        b = EkadashiDate(
          id: 21,
          name: 'Next',
          date: DateTime(2026, 11, 5),
          fastStartTime: '',
          fastBreakTime: '',
          description: '',
          fastingStartIso: '2026-11-05T06:00:00+05:30',
          paranaStartIso: '2026-11-06T06:00:00+05:30',
          paranaEndIso: '2026-11-06T08:00:00+05:30',
        );
    expect(
      EkadashiLifecycle.currentIndex(
        [a, b],
        DateTime.parse('2026-10-23T08:20:59+05:30'),
        'Asia/Kolkata',
      ),
      0,
    );
    expect(
      EkadashiLifecycle.currentIndex(
        [a, b],
        DateTime.parse(a.paranaEndIso),
        'Asia/Kolkata',
      ),
      1,
    );
    final day = EkadashiCalendarDay(
      [a, b],
      DateTime(2026, 10, 23),
      'Asia/Kolkata',
    );
    expect(day.fasting, isEmpty);
    expect(day.parana.single.occurrenceUid, a.occurrenceUid);
    expect(day.showsFastingMarker, isFalse);
  });
  test('minute-collapsed Parana stays valid without invented duration', () {
    final a = lifecycleEvent(end: '2026-10-23T06:00:00+05:30');
    expect(
      EkadashiLifecycle.of(
        a,
        DateTime.parse(a.fastingStartIso),
        'Asia/Kolkata',
      ).percent,
      0,
    );
    expect(
      EkadashiLifecycle.of(
        a,
        DateTime.parse(a.paranaEndIso),
        'Asia/Kolkata',
      ).phase,
      EkadashiPhase.passed,
    );
  });
}
