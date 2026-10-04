import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'package:ekadashi_calendar/services/practice_service.dart';
import 'package:ekadashi_calendar/services/practice_reminders.dart';

void main() {
  data.initializeTimeZones();
  const routine = PracticeRoutine(
    id: 'r',
    title: 'Morning',
    steps: ['chant'],
    weekdays: [1],
    reminderMinute: 540,
  );
  test(
    'weekday reminders follow local wall time across DST and respect consent',
    () {
      final zone = tz.getLocation('America/New_York');
      final now = tz.TZDateTime(zone, 2026, 3, 7, 10);
      final events = planPracticeReminders(
        [routine],
        now,
        premium: true,
        permitted: true,
      );
      expect(events, isNotEmpty);
      expect(events.first.at.weekday, DateTime.monday);
      expect(events.first.at.hour, 9);
      expect(events.first.at.timeZoneOffset, const Duration(hours: -4));
      expect(
        planPracticeReminders([routine], now, premium: true, permitted: false),
        isEmpty,
      );
      expect(
        planPracticeReminders([routine], now, premium: false, permitted: true),
        isEmpty,
      );
    },
  );
  test(
    'overnight quiet hours suppress reminders without changing the time',
    () {
      final now = tz.TZDateTime(tz.getLocation('Asia/Kolkata'), 2026, 10, 4);
      const late = PracticeRoutine(
        id: 'late',
        title: 'Night',
        steps: ['reflect'],
        reminderMinute: 1380,
      );
      expect(
        planPracticeReminders([late], now, premium: true, permitted: true),
        isEmpty,
      );
      final allowed = planPracticeReminders(
        [late],
        now,
        premium: true,
        permitted: true,
        quietStart: 0,
        quietEnd: 0,
      );
      expect(allowed.first.at.hour, 23);
    },
  );
  test(
    'native UTC alias schedules the selected weekday at local wall time',
    () {
      final zone = resolvePracticeTimeZone('Etc/UTC');
      final events = planPracticeReminders(
        [routine],
        tz.TZDateTime(zone, 2026, 10, 4, 8),
        premium: true,
        permitted: true,
      );
      expect(events.first.at.weekday, DateTime.monday);
      expect(events.first.at.hour, 9);
      expect(events.first.at.timeZoneOffset, Duration.zero);
      expect(resolvePracticeTimeZone('Asia/Calcutta').name, 'Asia/Kolkata');
    },
  );
}
