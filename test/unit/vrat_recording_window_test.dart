import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/vrat_recording.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Phase 4 (docs/ROADMAP.md): a fast can be recorded only once it is over:
/// past Ekadashis, and today's once its Parana begins.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  EkadashiDate event(DateTime date, {String parana = ''}) => EkadashiDate(
    id: 1,
    occurrenceUid: 'ekadashi:2026:20',
    name: 'Papankusha Ekadashi',
    date: date,
    fastStartTime: '',
    fastBreakTime: '',
    description: '',
    paranaStartIso: parana,
  );

  test('a future Ekadashi cannot be recorded', () {
    final future = event(
      DateTime(2026, 10, 22),
      parana: '2026-10-23T06:20:00+05:30',
    );
    expect(
      VratRecording.isOpen(
        future,
        now: DateTime.parse('2026-10-08T10:00:00+05:30'),
        timezone: 'IST',
      ),
      isFalse,
    );
  });

  test("today's Ekadashi opens when Parana begins", () {
    final today = event(
      DateTime(2026, 10, 22),
      parana: '2026-10-23T06:20:00+05:30',
    );
    bool open(String now) =>
        VratRecording.isOpen(today, now: DateTime.parse(now), timezone: 'IST');
    expect(open('2026-10-22T20:00:00+05:30'), isFalse, reason: 'still fasting');
    expect(open('2026-10-23T06:19:59+05:30'), isFalse);
    expect(open('2026-10-23T06:20:00+05:30'), isTrue);
  });

  test('a past Ekadashi is open even without a Parana time', () {
    expect(
      VratRecording.isOpen(
        event(DateTime(2026, 9, 7)),
        now: DateTime.parse('2026-10-08T10:00:00+05:30'),
        timezone: 'IST',
      ),
      isTrue,
    );
    expect(
      VratRecording.isOpen(
        event(DateTime(2026, 10, 8)),
        now: DateTime.parse('2026-10-08T23:00:00+05:30'),
        timezone: 'IST',
      ),
      isFalse,
    );
  });

  test('the bundled schedule opens only past fasts', () async {
    final service = EkadashiService();
    await service.initializeData();
    final now = DateTime.parse('2026-10-08T10:00:00+05:30');
    for (final e in service.getEkadashis(timezone: 'IST', languageCode: 'en')) {
      expect(
        VratRecording.isOpen(e, now: now, timezone: 'IST'),
        DateTime(
          e.date.year,
          e.date.month,
          e.date.day,
        ).isBefore(DateTime(2026, 10, 8)),
        reason: e.occurrenceUid,
      );
    }
  });
}
