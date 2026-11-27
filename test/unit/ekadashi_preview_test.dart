import 'dart:convert';

import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M52 first launch (27 November 2026): Home waited about 2 s for every
/// Ekadashi of 2026 and 2027 at a new place before showing any card. The
/// next weeks alone are a small part of that work and give the first card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const detected = PanchangCity(
    id: 'detected',
    label: 'Chennai (IN)',
    latitude: 13.01,
    longitude: 80.16,
    timeZoneId: 'Asia/Kolkata',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EkadashiSchedule.calculateInline = true;
    await EkadashiService().initializeData();
  });

  test('the next weeks are calculated alone, exactly as in the full year, '
      'and are not cached as a year', () async {
    final schedule = EkadashiService().schedule;
    const key = EkadashiScheduleKey(detected, EkadashiTradition.gaudiya, 2026);
    final preview = await schedule.preview(
      detected,
      EkadashiTradition.gaudiya,
      DateTime.utc(2026, 11, 27),
    );
    expect(preview, isNotEmpty);
    expect(preview.length, lessThan(6), reason: 'only the next weeks');
    expect(schedule.isCachedInMemory(key), isFalse);
    expect(
      (await SharedPreferences.getInstance()).getKeys().where(
        (k) => k.startsWith('ekadashi_schedule|'),
      ),
      isEmpty,
      reason: 'a preview is never saved as a year',
    );

    final year = await schedule.scheduled(key);
    for (final fast in preview.where((f) => f.date.startsWith('2026'))) {
      final same = year.firstWhere(
        (f) => f.occurrenceUid == fast.occurrenceUid,
      );
      expect(jsonEncode(fast.toJson()), jsonEncode(same.toJson()));
    }
    expect(preview.map((f) => f.contentId), contains('utpanna-ekadashi'));
  });
}
