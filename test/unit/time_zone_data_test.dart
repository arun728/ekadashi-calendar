import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:ekadashi_calendar/services/time_zone_data.dart';

void main() {
  setUpAll(initializeTimeZoneData);

  test('bundled database is IANA 2026b and keeps names the app relies on', () {
    expect(timeZoneDataRelease, '2026b');
    for (final name in [
      'UTC',
      'Asia/Kolkata',
      'Asia/Calcutta',
      'America/New_York',
      'America/Vancouver',
      'Pacific/Kiritimati',
      'Pacific/Chatham',
      'Australia/Lord_Howe',
      'Arctic/Longyearbyen',
    ]) {
      expect(() => tz.getLocation(name), returnsNormally, reason: name);
    }
  });

  test('British Columbia stays on UTC-7 after 1 November 2026', () {
    final vancouver = tz.getLocation('America/Vancouver');
    final before = tz.TZDateTime.from(
      DateTime.utc(2026, 10, 31, 12),
      vancouver,
    );
    final after = tz.TZDateTime.from(DateTime.utc(2026, 11, 2, 12), vancouver);
    expect(before.timeZoneOffset, const Duration(hours: -7));
    expect(after.timeZoneOffset, const Duration(hours: -7));
    // Other North American zones still fall back.
    final newYork = tz.TZDateTime.from(
      DateTime.utc(2026, 11, 2, 12),
      tz.getLocation('America/New_York'),
    );
    expect(newYork.timeZoneOffset, const Duration(hours: -5));
  });
}
