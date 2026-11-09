import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_key_days.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_terms.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:ekadashi_calendar/services/search/search_corpus.dart';
import 'package:ekadashi_calendar/services/search/unified_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const engine = PanchangEngine();
  const lunarIds = {'purnima', 'amavasya'};
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/panchang/lunar_start_dates_2026_2027.json',
            ).readAsStringSync(),
          )
          as Map;
  String iso(DateTime d) => d.toIso8601String().substring(0, 10);
  late SearchCatalog catalog;
  late PanchangTerms terms;
  setUpAll(() async {
    catalog = await SearchCatalog.load();
    terms = await PanchangTerms.load();
  });

  for (final row in fixture['cities'] as List) {
    final city = PanchangCity(
      id: row['id'],
      label: row['label'],
      latitude: row['lat'] + 0.0,
      longitude: row['lon'] + 0.0,
      timeZoneId: row['tz'],
    );
    for (final year in [2026, 2027]) {
      test(
        'local lunar start dates without end-day duplicates: ${city.id} $year',
        () {
          final expected = <String>[];
          for (final interval in fixture['intervals'] as List) {
            final local = city.wallClock(DateTime.parse(interval['start']));
            if (local.year == year) {
              expected.add(
                "${interval['tithi'] == 15 ? 'purnima' : 'amavasya'}:${iso(DateTime.utc(local.year, local.month, local.day))}",
              );
            }
          }
          expected.sort();
          final actual =
              engine
                  .observanceCalendar(year, city: city)
                  .where((x) => lunarIds.contains(x.observance.id))
                  .map((x) => '${x.observance.id}:${iso(x.date)}')
                  .toList()
                ..sort();
          expect(actual, expected);
          expect(actual.toSet().length, actual.length);
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }

  test(
    'phase boundaries and every other Chennai observance stay unchanged',
    () {
      for (final row in fixture['intervals'] as List) {
        final start = DateTime.parse(row['start']);
        final end = DateTime.parse(row['end']);
        final probe = start.add(const Duration(minutes: 1));
        expect(engine.tithiAt(probe).index, row['tithi']);
        expect(
          engine.tithiStart(probe).difference(start).inMicroseconds.abs(),
          lessThan(10000),
        );
        expect(
          engine.tithiAt(probe).endsAtUtc!.difference(end).inMicroseconds.abs(),
          lessThan(10000),
        );
      }
      for (final row in fixture['other_chennai_observances'] as List) {
        final actual =
            engine
                .observancesOn(
                  DateTime.parse(row['date']),
                  city: PanchangCity.chennai,
                )
                .where((x) => !lunarIds.contains(x.id))
                .map((x) => x.id)
                .toList()
              ..sort();
        expect(actual, row['ids'], reason: row['date']);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('daily and calendar paths agree on start, end and polar days', () {
    const polar = PanchangCity(
      id: 'tromso',
      label: 'Tromso',
      latitude: 69.6492,
      longitude: 18.9553,
      timeZoneId: 'Europe/Oslo',
    );
    for (final city in [PanchangCity.chennai, PanchangCity.newYork, polar]) {
      for (final text in [
        '2026-11-08',
        '2026-11-09',
        '2027-06-18',
        '2027-12-12',
        '2027-12-13',
      ]) {
        final date = DateTime.parse(text);
        List<String> ids(List<PanchangObservance> events) =>
            events.map((x) => x.id).toList();
        expect(
          ids(engine.calculate(date, city: city).observances),
          ids(engine.observancesOn(date, city: city)),
        );
      }
    }
    expect(
      engine
          .observancesOn(DateTime.utc(2026, 11, 8), city: PanchangCity.chennai)
          .map((x) => x.id),
      contains('amavasya'),
    );
    expect(
      engine
          .observancesOn(DateTime.utc(2026, 11, 9), city: PanchangCity.chennai)
          .map((x) => x.id),
      isNot(contains('amavasya')),
    );
    expect(
      engine
          .observancesOn(DateTime.utc(2027, 6, 18), city: polar)
          .map((x) => x.id),
      contains('purnima'),
    );
  });

  test('all category filters isolate festivals and preserve name search', () {
    final date = DateTime.utc(2027, 7, 18);
    SearchItem item(String id, String title, List<SearchCategory> categories) =>
        SearchItem(
          id: id,
          target: SearchTarget.observance(id, date),
          categories: categories,
          title: title,
          titleEnglish: title,
          names: [title],
          text: '',
          date: date,
          requiresPremium: true,
        );
    for (final category in SearchCategory.filters.where(
      (c) =>
          c != SearchCategory.festival &&
          c != SearchCategory.myCalendar &&
          c != SearchCategory.ekadashi,
    )) {
      final search = UnifiedSearch([
        item('monthly', 'Monthly', [category]),
        item('festival', 'Guru Purnima', [SearchCategory.festival, category]),
      ], catalog);
      expect(
        search
            .search('', category: category, year: 2027, today: date)
            .map((x) => x.id),
        ['monthly'],
      );
      expect(search.search('guru', category: category, today: date), isEmpty);
      expect(
        search
            .search(
              '',
              category: SearchCategory.festival,
              year: 2027,
              today: date,
            )
            .map((x) => x.id),
        ['festival'],
      );
      expect(
        search.search('', year: 2027, today: date).map((x) => x.id).toSet(),
        {'monthly', 'festival'},
      );
      KeyDay day(String id, List<SearchCategory> categories) => KeyDay(
        id: id,
        key: id,
        date: date,
        title: id,
        categories: categories,
        requiresPremium: true,
      );
      final days = [
        day('monthly', [category]),
        day('festival', [SearchCategory.festival, category]),
      ];
      expect(PanchangKeyDays.filter(days, category).map((x) => x.id), [
        'monthly',
      ]);
      expect(
        PanchangKeyDays.filter(days, SearchCategory.festival).map((x) => x.id),
        ['festival'],
      );
    }
    final search = UnifiedSearch([
      item('guru', 'Guru Purnima', [
        SearchCategory.festival,
        SearchCategory.purnima,
      ]),
    ], catalog);
    expect(search.search('guru purnima', today: date).map((x) => x.id), [
      'guru',
    ]);
    expect(search.search('purnima', today: date), isEmpty);
    expect(
      search.search(
        '',
        category: SearchCategory.festival,
        year: 2026,
        today: date,
      ),
      isEmpty,
    );
  });

  test(
    'monthly Vinayaka is named consistently in every language, annual Ganesh is preserved',
    () {
      const monthly = PanchangObservance(
        id: 'vinayaka-chaturthi',
        name: 'Vinayaka Chaturthi (monthly)',
        ruleSource: 'calculated',
        description: '',
        isMajor: true,
      );
      const annual = PanchangObservance(
        id: 'vinayaka-chaturthi',
        name: 'Ganesh Chaturthi',
        ruleSource: 'calculated',
        description: '',
        isMajor: true,
      );
      for (final entry in (fixture['monthly_names'] as Map).entries) {
        final language = entry.key as String;
        expect(terms.observanceName(monthly, language), entry.value);
        final dated = DatedObservance(
          date: DateTime.utc(2027, 2, 9),
          observance: monthly,
        );
        expect(
          SearchCorpus.observanceItems([dated], language, catalog).single.title,
          entry.value,
        );
        expect(
          PanchangKeyDays.month(
            dated.date,
            observances: [dated],
            ekadashis: [],
            language: language,
            catalog: catalog,
          ).single.title,
          entry.value,
        );
      }
      expect(terms.observanceName(annual, 'en'), 'Ganesh Chaturthi');
      expect(
        catalog.observance(annual.id, annual.name)?.key,
        'ganesh-chaturthi',
      );
    },
  );
}
