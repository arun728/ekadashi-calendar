import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_models.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:ekadashi_calendar/services/search/search_corpus.dart';
import 'package:ekadashi_calendar/services/search/search_text.dart';
import 'package:ekadashi_calendar/services/search/unified_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Phase 1 search on Android: the same catalog, ranking and golden cases as
/// the iOS UnifiedSearchTests (test/fixtures/search/search_golden.json).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EkadashiService();
  late SearchCatalog catalog;
  late Map<String, dynamic> fixture;
  late List<DatedObservance> observances;
  late List<CalendarEntry> entries;
  final searches = <String, UnifiedSearch>{};

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await service.initializeData();
    catalog = await SearchCatalog.load();
    fixture =
        jsonDecode(
              File(
                'test/fixtures/search/search_golden.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(fixture['city'], PanchangCity.newDelhi.id);
    const engine = PanchangEngine();
    observances = [
      for (final year in fixture['years'] as List)
        ...engine.observanceCalendar(year as int, city: PanchangCity.newDelhi),
    ];
    entries = [
      for (final row in fixture['entries'] as List)
        () {
          final date = DateTime.parse(row['date'] as String);
          // 09:00 at UTC+05:30.
          final start = DateTime.utc(date.year, date.month, date.day, 3, 30);
          return CalendarEntry(
            id: row['id'] as String,
            title: row['title'] as String,
            notes: row['notes'] as String?,
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
            isAllDay: false,
            source: row['source'] == 'google'
                ? CalendarEntrySource.google
                : CalendarEntrySource.custom,
            calendarName: row['calendar'] as String?,
            updatedAt: start,
          );
        }(),
    ];
  });

  UnifiedSearch search(String language) => searches[language] ??= UnifiedSearch(
    SearchCorpus.build(
      ekadashis: (code) =>
          service.getEkadashis(timezone: 'IST', languageCode: code),
      observances: observances,
      entries: entries,
      language: language,
      catalog: catalog,
    ),
    catalog,
  );

  test('golden cases match the iOS search', () {
    final today = DateTime.parse(fixture['today'] as String);
    final english = {
      for (final item in search('en').items) item.id: item.titleEnglish,
    };
    final failures = <String>[];
    for (final row in fixture['cases'] as List) {
      final query = row['query'] as String;
      final language = row['language'] as String? ?? 'en';
      final label =
          "$language '$query' ${row['category'] ?? ''} ${row['year_filter'] ?? ''}";
      final results = search(language).search(
        query,
        category: row['category'] == null
            ? null
            : SearchCategory.parse(row['category'] as String),
        year: row['year_filter'] as int?,
        today: today,
      );
      void check(bool ok, String what) {
        if (!ok) {
          failures.add(
            '$label: $what (got ${results.take(3).map((r) => r.id).toList()})',
          );
        }
      }

      if (row['count'] != null) {
        check(results.length == row['count'], 'count ${results.length}');
      }
      if (row['top'] != null) {
        check(results.firstOrNull?.id == row['top'], 'top ${row['top']}');
      }
      if (row['top_prefix'] != null) {
        check(
          results.firstOrNull?.id.startsWith(row['top_prefix'] as String) ==
              true,
          'top_prefix',
        );
      }
      if (row['top_title'] != null) {
        check(results.firstOrNull?.title == row['top_title'], 'top_title');
      }
      if (row['top_title_en'] != null) {
        check(
          english[results.firstOrNull?.id] == row['top_title_en'],
          'top_title_en',
        );
      }
      if (row['all_categories'] != null) {
        final category = SearchCategory.parse(row['all_categories'] as String)!;
        check(
          results.isNotEmpty &&
              results.every((r) => r.categories.contains(category)),
          'all_categories',
        );
      }
      if (row['all_in_year'] != null) {
        check(
          results.isNotEmpty &&
              results.every((r) => r.date?.year == row['all_in_year']),
          'all_in_year',
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('only Panchang observances need Premium', () {
    for (final item in search('en').items) {
      expect(
        item.requiresPremium,
        item.target.kind == SearchTargetKind.observance,
        reason: item.id,
      );
    }
  });

  test('titles follow the app language', () {
    const expected = {
      'en': 'Deepavali (Lakshmi Puja)',
      'hi': 'दीपावली (लक्ष्मी पूजा)',
      'ta': 'தீபாவளி',
      'te': 'దీపావళి',
    };
    for (final MapEntry(key: language, value: title) in expected.entries) {
      final items = search(language).items;
      expect(
        items
            .firstWhere((i) => i.id == 'observance:deepavali:2026-11-08')
            .title,
        title,
      );
      expect(
        items.firstWhere((i) => i.id == 'screen:notifications').title,
        AppStrings.translate('notifications', language),
      );
    }
  });

  test('ranking tiers and matching helpers', () {
    expect(SearchText.normalize('Mōhinī  Ekadashi!'), 'm hin ekadashi');
    expect(SearchText.tokenDistance('ekadsahi', 'ekadashi'), 1);
    expect(SearchText.tokenDistance('abc', 'abd'), isNull);
    expect(SearchText.isSubsequence('ekdsh', 'ekadashi'), isTrue);
    expect(AppLanguage.codes, ['en', 'hi', 'ta', 'te']);
  });

  test(
    'every Panchang observance the engine names is catalogued or excluded',
    () {
      final unknown = <String>{};
      for (final dated in observances) {
        final o = dated.observance;
        if (!o.isMajor || catalog.excludedEngineIds.contains(o.id)) continue;
        if (catalog.observance(o.id, o.name) == null) unknown.add(o.id);
      }
      expect(unknown, isEmpty);
    },
  );
}
