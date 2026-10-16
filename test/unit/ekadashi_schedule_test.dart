import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/ekadashi_schedule.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home, Calendar, reminders and widgets take Ekadashi dates and times from
/// the Panchang engine for the chosen city and tradition, keeping the
/// published identities (EkadashiScheduleTests.swift).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Map<String, dynamic>> pack(int year) =>
      ((jsonDecode(File('assets/calendar/$year.json').readAsStringSync())
                  as Map<String, dynamic>)['ekadashis']
              as List)
          .cast<Map<String, dynamic>>();

  String ist(Map<String, dynamic> row, String field) =>
      row['timing']['IST'][field] as String;

  const chennai = PanchangCity(
    id: 'geonames-1264527',
    label: 'Chennai (IN)',
    latitude: 13.08784,
    longitude: 80.27847,
  );
  const newDelhi = PanchangCity(
    id: 'geonames-1261481',
    label: 'New Delhi (IN)',
    latitude: 28.62137,
    longitude: 77.2148,
  );
  const newYork = PanchangCity(
    id: 'geonames-5128581',
    label: 'New York City (US)',
    latitude: 40.71427,
    longitude: -74.00597,
    timeZoneId: 'America/New_York',
  );
  const london = PanchangCity(
    id: 'geonames-2643743',
    label: 'London (GB)',
    latitude: 51.50853,
    longitude: -0.12574,
    timeZoneId: 'Europe/London',
  );
  const sydney = PanchangCity(
    id: 'geonames-2147714',
    label: 'Sydney (AU)',
    latitude: -33.86785,
    longitude: 151.20732,
    timeZoneId: 'Australia/Sydney',
  );

  double minutesApart(String a, String b) =>
      DateTime.parse(a).difference(DateTime.parse(b)).inSeconds.abs() / 60;

  List<ScheduledEkadashi> schedule(
    PanchangCity city,
    EkadashiTradition tradition,
    int year,
  ) => EkadashiSchedule.calculate(
    EkadashiScheduleKey(city, tradition, year),
    year == 2026 || year == 2027 ? pack(year) : const [],
  );

  test('enabled years come from the shared config', () {
    final asset = File(
      'assets/calendar/ekadashi_years.json',
    ).readAsStringSync();
    expect(EkadashiYears.parse(asset), [2026, 2027]);
    expect(
      File(
        'ios-native/EkadashiCore/Sources/EkadashiCore/Resources/calendar/ekadashi_years.json',
      ).readAsStringSync(),
      asset,
    );
    expect(
      EkadashiYears.defaultYear(DateTime(2026, 10, 13), [2026, 2027]),
      2026,
    );
    expect(EkadashiYears.defaultYear(DateTime(2028, 2, 1), [2026, 2027]), 2027);
  });

  test('Chennai Smarta 2026 is the published 2026 schedule', () {
    final rows = pack(2026);
    final fasts = schedule(chennai, EkadashiTradition.smarta, 2026);
    expect(
      fasts.map((f) => f.occurrenceUid),
      rows.map((r) => r['occurrence_uid']),
    );
    expect(fasts.map((f) => f.date), rows.map((r) => ist(r, 'date')));
    expect(
      fasts.map((f) => f.notificationId),
      rows.map((r) => r['notification_id']),
    );
  });

  // Raw boundaries retain seconds; use the existing independent two-minute
  // published-source tolerance (minute truncation previously hid up to 1.21 min).
  test('New Delhi 2027 keeps identities and adds the 23 Dec Saphala', () {
    final rows = pack(2027);
    final fasts = schedule(newDelhi, EkadashiTradition.smarta, 2027);
    expect(fasts, hasLength(25));
    for (var i = 0; i < rows.length; i++) {
      expect(fasts[i].occurrenceUid, rows[i]['occurrence_uid']);
      expect(fasts[i].date, ist(rows[i], 'date'));
      expect(
        minutesApart(fasts[i].fastingStart, ist(rows[i], 'fasting_start')),
        lessThanOrEqualTo(2),
      );
      expect(
        minutesApart(fasts[i].paranaStart, ist(rows[i], 'parana_start')),
        lessThanOrEqualTo(2),
      );
      expect(
        minutesApart(fasts[i].paranaEnd, ist(rows[i], 'parana_end')),
        lessThanOrEqualTo(2),
      );
    }
    final saphala = fasts.last;
    expect(saphala.date, '2027-12-23');
    expect(saphala.contentId, 'saphala-ekadashi');
    expect(saphala.occurrenceUid, 'ekadashi:2027:25');
    expect(saphala.notificationId, 2027025);
    expect(saphala.publishedUid, isNull);
  });

  test('a Vaishnava fast a day later keeps the published identity', () {
    final smarta = schedule(chennai, EkadashiTradition.smarta, 2026);
    final gaudiya = schedule(chennai, EkadashiTradition.gaudiya, 2026);
    expect(
      gaudiya.map((f) => f.occurrenceUid).toSet(),
      smarta.map((f) => f.occurrenceUid).toSet(),
    );
    final yogini = gaudiya.firstWhere((f) => f.contentId == 'yogini-ekadashi');
    expect(yogini.date, '2026-07-11');
    expect(
      yogini.occurrenceUid,
      smarta.firstWhere((f) => f.contentId == 'yogini-ekadashi').occurrenceUid,
    );
  });

  test('Home matches the Panchang Ekadashi sub-tab to the minute worldwide', () {
    final mismatches = <String>[];
    for (final city in [chennai, newYork, london, sydney]) {
      for (final tradition in EkadashiTradition.values) {
        final panel = <CalculatedEkadashi>[];
        for (var month = 1; month <= 12; month++) {
          final first = DateTime.utc(2026, month);
          final days = DateTime.utc(2026, month + 1).difference(first).inDays;
          panel.addAll(
            const CalculatedEkadashiEngine().calculate(
              first,
              days,
              city,
              tradition,
            ),
          );
        }
        final home = schedule(city, tradition, 2026);
        if (home.length != panel.length) {
          mismatches.add('${city.label} ${tradition.name} count');
          continue;
        }
        for (var i = 0; i < home.length; i++) {
          void same(String iso, DateTime? instant, String what) {
            if (instant == null) return;
            final wall = city.wallClock(instant);
            final shown = DateTime.parse(iso.substring(0, 16));
            if (shown.year != wall.year ||
                shown.month != wall.month ||
                shown.day != wall.day ||
                shown.hour != wall.hour ||
                shown.minute != wall.minute) {
              mismatches.add(
                '${city.label} ${tradition.name} ${home[i].date} $what $iso vs $wall',
              );
            }
          }

          same(home[i].fastingStart, panel[i].fastStartsUtc, 'fast');
          same(home[i].paranaStart, panel[i].paranaStartUtc, 'parana start');
          same(home[i].paranaEnd, panel[i].paranaEndUtc, 'parana end');
        }
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.take(10).join('\n'));
  });

  test(
    'screens asking at once share one calculation, which finishes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final schedule = EkadashiSchedule(publishedRows: pack);
      const key = EkadashiScheduleKey(chennai, EkadashiTradition.smarta, 2026);
      final both = await Future.wait([
        schedule.scheduled(key),
        schedule.scheduled(key),
      ]).timeout(const Duration(minutes: 1));
      expect(identical(both[0], both[1]), isTrue);
      expect(schedule.cached(key), same(both[0]));
      expect(await schedule.scheduled(key), same(both[0]));
      // Stored on the phone: a new session reads it back unchanged.
      final again = await EkadashiSchedule(publishedRows: pack).scheduled(key);
      expect(again, both[0]);
    },
  );

  test('a future year needs no new data', () {
    final fasts = schedule(chennai, EkadashiTradition.smarta, 2028);
    expect(fasts.length, inInclusiveRange(24, 25));
    expect(fasts.first.occurrenceUid, 'ekadashi:2028:01');
    expect(fasts.first.notificationId, 2028001);
    final contentIds = {
      for (final year in [2026, 2027])
        for (final row in pack(year)) row['content_id'],
    };
    for (final tradition in EkadashiTradition.values) {
      for (final year in [2028, 2029]) {
        for (final fast in schedule(newDelhi, tradition, year)) {
          expect(
            contentIds,
            contains(fast.contentId),
            reason: '$year ${fast.contentId}',
          );
        }
      }
    }
  });

  test('engine names and months map to published keys', () {
    expect(
      EkadashiSchedule.contentIdForEngineName('Devutthana Ekadashi'),
      'prabodhini-ekadashi',
    );
    expect(EkadashiSchedule.monthKey('Ashvina'), 'ashwin');
    expect(EkadashiSchedule.monthKey('Adhika Jyeshtha'), 'adhika');
  });

  test('every city shows its time zone like IST', () {
    final summer = DateTime.utc(2026, 7, 1, 12),
        winter = DateTime.utc(2026, 1, 15, 12);
    PanchangCity zone(String id) => PanchangCity(
      id: 't',
      label: 'T',
      latitude: 0,
      longitude: 0,
      timeZoneId: id,
    );
    expect(zone('Asia/Kolkata').timeZoneLabel('en', now: summer), 'IST');
    expect(zone('America/New_York').timeZoneLabel('en', now: summer), 'EDT');
    expect(zone('America/New_York').timeZoneLabel('en', now: winter), 'EST');
    expect(zone('Europe/London').timeZoneLabel('en', now: winter), 'GMT');
    expect(zone('Europe/London').timeZoneLabel('en', now: summer), 'BST');
    expect(zone('Australia/Sydney').timeZoneLabel('en', now: winter), 'AEDT');
    expect(zone('Asia/Dubai').timeZoneLabel('en', now: summer), 'UTC+4');
    expect(zone('Asia/Kathmandu').timeZoneLabel('en', now: summer), 'UTC+5:45');
    for (final language in ['hi', 'ta', 'te', 'gu', 'bn']) {
      expect(
        RegExp('[A-Za-z]').hasMatch(
          zone('America/New_York').timeZoneLabel(language, now: summer),
        ),
        isFalse,
        reason: language,
      );
    }
  });

  test('recent picks come first, then popular cities; never empty', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await RecentCities.shortlist()).popular, isNotEmpty);
    final popular = await PanchangLocationStore.popular();
    expect(popular, hasLength(PanchangLocationStore.popularIds.length));
    expect(popular.first.label, 'Chennai (IN)');
    final ldn = popular.firstWhere((c) => c.label.startsWith('London'));
    final syd = popular.firstWhere((c) => c.label.startsWith('Sydney'));
    await RecentCities.add(ldn);
    await RecentCities.add(syd);
    await RecentCities.add(ldn);
    expect((await RecentCities.all()).map((c) => c.id), [ldn.id, syd.id]);
    final list = await RecentCities.shortlist();
    expect(list.popular.any((c) => c.id == ldn.id || c.id == syd.id), isFalse);
  });
}
