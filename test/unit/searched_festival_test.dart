import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:ekadashi_calendar/services/time_zone_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widely searched festivals added in October 2026, checked against Drik
/// Panchang's New Delhi calendars for 2026-2027 and Prokerala's pages
/// (test/fixtures/panchang/searched_festivals.json, SearchedFestivalTests).
void main() {
  setUpAll(initializeTimeZoneData);
  const engine = PanchangEngine();
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/panchang/searched_festivals.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final festivals = (fixture['festivals'] as List).cast<Map>();
  PanchangCity city(String id) {
    final row = fixture['cities'][id] as Map;
    return PanchangCity(
      id: id,
      label: id,
      latitude: (row['lat'] as num).toDouble(),
      longitude: (row['lon'] as num).toDouble(),
      timeZoneId: row['tz'] as String,
    );
  }

  final calendars = <String, List<DatedObservance>>{};
  List<DatedObservance> calendar(PanchangCity place, int year) =>
      calendars['${place.id}|$year'] ??= engine.observanceCalendar(
        year,
        city: place,
      );
  List<String> dates(String id, PanchangCity place, int year) => [
    for (final dated in calendar(place, year))
      if (dated.observance.id == id)
        dated.date.toIso8601String().substring(0, 10),
  ];

  test('published dates', () {
    final failures = <String>[];
    for (final row in festivals) {
      final id = row['id'] as String;
      final place = city(row['city'] as String);
      for (final date in (row['dates'] as List).cast<String>()) {
        final found = dates(id, place, int.parse(date.substring(0, 4)));
        if (found.length != 1 || found.single != date) {
          failures.add('$id ${date.substring(0, 4)}: $found vs $date');
        }
      }
    }
    expect(failures, isEmpty);
  });

  test('the engine lists exactly the fixture festivals', () {
    expect(PanchangEngine.searchedFestivalIds, {
      for (final row in festivals) row['id'] as String,
    });
  });

  test('each happens once a year and is major', () {
    for (final id in PanchangEngine.searchedFestivalIds) {
      for (final year in const [2026, 2027]) {
        final found = [
          for (final dated in calendar(PanchangCity.newDelhi, year))
            if (dated.observance.id == id) dated.observance,
        ];
        expect(found, hasLength(1), reason: '$id $year');
        expect(found.single.isMajor, isTrue, reason: id);
      }
    }
  });

  test('searchable and named in every language', () {
    final catalog = SearchCatalog.parse(
      File(SearchCatalog.asset).readAsStringSync(),
    );
    for (final id in PanchangEngine.searchedFestivalIds) {
      final observance = calendar(
        PanchangCity.newDelhi,
        2026,
      ).firstWhere((d) => d.observance.id == id).observance;
      final entry = catalog.observance(id, observance.name);
      expect(entry, isNotNull, reason: id);
      for (final language in const ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
        final name = entry!.names[language];
        expect(name, isNotNull, reason: '$id $language');
        if (language != 'en') {
          expect(name, isNot(matches(RegExp('[A-Za-z]'))), reason: name);
        }
      }
    }
  });
}
