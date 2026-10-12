import '../../l10n/app_language.dart';
import '../../models/calendar_entry.dart';
import '../ekadashi_service.dart';
import '../panchang/panchang_models.dart';
import 'search_catalog.dart';
import 'unified_search.dart';

/// Builds the search items for the whole app (docs/ROADMAP.md Phase 1),
/// like the Swift `SearchCorpus`. Titles follow the app language; every
/// language's name stays searchable.
class SearchCorpus {
  const SearchCorpus._();

  static DateTime civil(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  static List<SearchItem> build({
    required List<EkadashiDate> Function(String language) ekadashis,
    required List<DatedObservance> observances,
    required List<CalendarEntry> entries,
    required String language,
    required SearchCatalog catalog,
  }) => [
    ...ekadashiItems(ekadashis, language),
    ...observanceItems(observances, language, catalog),
    ...entryItems(entries),
    ...screenItems(language, catalog),
  ];

  /// Published Ekadashis (free). [ekadashis] returns the schedule in a language.
  static List<SearchItem> ekadashiItems(
    List<EkadashiDate> Function(String language) ekadashis,
    String language,
  ) {
    final namesByUid = <String, List<String>>{};
    final english = <String, String>{};
    for (final code in AppLanguage.codes) {
      for (final event in ekadashis(code)) {
        (namesByUid[event.occurrenceUid] ??= []).add(event.name);
        if (code == 'en') english[event.occurrenceUid] = event.name;
      }
    }
    return [
      for (final event in ekadashis(language))
        SearchItem(
          id: event.occurrenceUid,
          target: SearchTarget.ekadashi(event.occurrenceUid),
          categories: const [SearchCategory.ekadashi],
          title: event.name,
          titleEnglish: english[event.occurrenceUid] ?? event.name,
          names: namesByUid[event.occurrenceUid] ?? [event.name],
          text: '${event.description} ${event.paksha} ${event.month}',
          date: civil(event.date),
          requiresPremium: false,
        ),
    ];
  }

  /// Calculated Panchang observances that the catalogue knows (Premium).
  static List<SearchItem> observanceItems(
    List<DatedObservance> observances,
    String language,
    SearchCatalog catalog,
  ) {
    final seen = <String>{};
    final items = <SearchItem>[];
    for (final dated in observances) {
      if (catalog.excludedEngineIds.contains(dated.observance.id)) continue;
      final entry = catalog.observance(
        dated.observance.id,
        dated.observance.name,
      );
      if (entry == null) continue;
      final date = civil(dated.date);
      final id = 'observance:${entry.key}:${iso(date)}';
      if (!seen.add(id)) continue;
      items.add(
        SearchItem(
          id: id,
          target: SearchTarget.observance(entry.key, date),
          categories: entry.categories,
          title: entry.name(language),
          titleEnglish: entry.name('en'),
          names: [
            for (final code in AppLanguage.codes) entry.name(code),
            ...entry.aliases,
          ],
          text: '',
          date: date,
          requiresPremium: true,
        ),
      );
    }
    return items;
  }

  /// Custom entries and imported Google events, on the day they start.
  static List<SearchItem> entryItems(List<CalendarEntry> entries) => [
    for (final entry in entries)
      SearchItem(
        id: 'entry:${entry.id}',
        target: SearchTarget.entry(entry.id, civil(entry.localStart)),
        categories: const [SearchCategory.myCalendar],
        title: entry.title,
        titleEnglish: entry.title,
        names: [entry.title],
        text: [
          entry.notes,
          entry.calendarName,
          entry.source == CalendarEntrySource.google ? 'google' : 'custom',
        ].whereType<String>().join(' '),
        date: civil(entry.localStart),
        requiresPremium: false,
      ),
  ];

  /// App screens and settings.
  static List<SearchItem> screenItems(String language, SearchCatalog catalog) =>
      [
        for (final screen in catalog.screens)
          SearchItem(
            id: 'screen:${screen.key}',
            target: screen.target,
            categories: const [SearchCategory.screen],
            title: AppStrings.translate(screen.titleKey, language),
            titleEnglish: AppStrings.translate(screen.titleKey, 'en'),
            names: [
              for (final code in AppLanguage.codes)
                AppStrings.translate(screen.titleKey, code),
              ...screen.aliases,
            ],
            text: '',
            date: null,
            requiresPremium: false,
          ),
      ];

  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
