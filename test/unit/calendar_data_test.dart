import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EkadashiService();
  late List<dynamic> rawEvents;
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await service.initializeData();
    rawEvents =
        (jsonDecode(await rootBundle.loadString('assets/ekadashi_data.json'))
                as Map)['ekadashis']
            as List;
  });
  const zones = {
    'IST': 'Asia/Kolkata',
    'EST': 'America/New_York',
    'CST': 'America/Chicago',
    'MST': 'America/Denver',
    'PST': 'America/Los_Angeles',
  };
  for (final zone in zones.entries) {
    test(
      '${zone.key} data is complete, ordered, uniquely keyed and UTC-consistent',
      () {
        final events = service.getEkadashis(
          timezone: zone.key,
          languageCode: 'en',
        );
        expect(events, hasLength(rawEvents.length));
        expect(events.map((e) => e.id).toSet(), hasLength(events.length));
        final location = tz.getLocation(zone.value);
        for (var i = 0; i < events.length; i++) {
          final e = events[i];
          expect(e.id, greaterThan(0));
          expect(e.name, isNotEmpty);
          expect(e.description, isNotEmpty);
          expect(e.story, isNotEmpty);
          if (i > 0) expect(e.date.isAfter(events[i - 1].date), isTrue);
          final start = DateTime.parse(e.fastingStartIso);
          final parana = DateTime.parse(e.paranaStartIso);
          final end = DateTime.parse(e.paranaEndIso);
          expect(
            start.isBefore(parana),
            isTrue,
            reason: '${e.id} fasting must precede Parana',
          );
          expect(
            parana.isBefore(end),
            isTrue,
            reason: '${e.id} Parana window must have positive length',
          );
          for (final iso in [
            e.fastingStartIso,
            e.paranaStartIso,
            e.paranaEndIso,
          ]) {
            final instant = DateTime.parse(iso);
            final local = tz.TZDateTime.from(instant, location);
            // Offsets and wall time must agree even during DST; this does not
            // claim astronomical or city-specific sunrise accuracy.
            final storedWallTime = DateTime.parse(iso.substring(0, 19));
            expect(local.hour, storedWallTime.hour, reason: iso);
            expect(local.minute, storedWallTime.minute, reason: iso);
          }
          final localStart = tz.TZDateTime.from(start, location);
          expect(
            [localStart.year, localStart.month, localStart.day],
            [e.date.year, e.date.month, e.date.day],
          );
          expect(e.fastStartTime, matches(RegExp(r'^\d{2}:\d{2} (AM|PM)$')));
          expect(
            e.fastBreakTime,
            matches(RegExp(r'^\d{2}:\d{2} (AM|PM) - \d{2}:\d{2} (AM|PM)$')),
          );
        }
      },
    );
    for (final lang in ['en', 'ta', 'hi']) {
      test(
        '${zone.key}/$lang uses matching translated content without changing occurrence identity',
        () {
          final events = service.getEkadashis(
            timezone: zone.key,
            languageCode: lang,
          );
          for (final e in events) {
            final raw = rawEvents.cast<Map>().singleWhere(
              (r) => r['id'] == e.id,
            );
            expect(
              e.name,
              (raw['name'] as Map)[lang] ?? (raw['name'] as Map)['en'],
            );
            expect(
              e.story,
              (raw['story'] as Map)[lang] ?? (raw['story'] as Map)['en'],
            );
            expect(
              e.fastingRules,
              (raw['fasting_rules'] as Map)[lang] ??
                  (raw['fasting_rules'] as Map)['en'],
            );
          }
        },
      );
    }
  }
  test('Unknown content language falls back to English for every event', () {
    final fallback = service.getEkadashis(timezone: 'IST', languageCode: 'xx');
    final english = service.getEkadashis(timezone: 'IST', languageCode: 'en');
    for (var i = 0; i < english.length; i++) {
      expect(fallback[i].name, english[i].name);
      expect(fallback[i].story, english[i].story);
      expect(fallback[i].description, english[i].description);
    }
  });
  test('Timezone/language cache stays isolated and can be rebuilt', () {
    final india = service.getEkadashis(timezone: 'IST', languageCode: 'en');
    final west = service.getEkadashis(timezone: 'PST', languageCode: 'ta');
    expect(west.first.date, isNot(india.first.date));
    expect(west.first.name, isNot(india.first.name));
    service.clearCache();
    final rebuilt = service.getEkadashis(timezone: 'IST', languageCode: 'en');
    expect(
      rebuilt.map((e) => e.fastingStartIso),
      india.map((e) => e.fastingStartIso),
    );
  });
  test('Unavailable timezone supplies no invented occurrences', () {
    expect(
      service.getEkadashis(timezone: 'UNSUPPORTED', languageCode: 'en'),
      isEmpty,
    );
  });
  test('City selection round-trips country and supported timezone', () {
    final groups = service.getCitiesByCountry();
    expect(groups.keys, containsAll(['India', 'United States']));
    for (final cities in groups.values) {
      for (final city in cities) {
        expect(service.getCityById(city.id)?.name, city.name);
        expect(service.getTimezoneForCity(city.id), city.timezone);
        expect(EkadashiService.supportedTimezones, contains(city.timezone));
      }
    }
    expect(service.getCityById('no-such-city'), isNull);
  });
}
