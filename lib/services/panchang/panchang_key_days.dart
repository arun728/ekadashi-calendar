import '../ekadashi_service.dart';
import '../search/search_catalog.dart';
import 'panchang_models.dart';

/// One important day in the Panchang's Key days list.
class KeyDay {
  const KeyDay({
    required this.id,
    required this.key,
    required this.date,
    required this.title,
    required this.categories,
    required this.requiresPremium,
  });

  /// `<occurrence uid>` for published Ekadashis, else `<catalogue key>:<date>`.
  final String id;

  /// The catalogue key (null for published Ekadashis).
  final String? key;

  /// The civil date (UTC midnight).
  final DateTime date;
  final String title;
  final List<SearchCategory> categories;

  /// Panchang observances are Premium; published Ekadashis are free.
  final bool requiresPremium;
}

/// The month's Ekadashis (published schedule, authoritative) and catalogued
/// Panchang observances (Amavasya, Purnima, Shivaratri, festivals, ...),
/// like the Swift `PanchangKeyDays`.
class PanchangKeyDays {
  const PanchangKeyDays._();

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<KeyDay> month(
    DateTime month, {
    required List<DatedObservance> observances,
    required List<EkadashiDate> ekadashis,
    required String language,
    required SearchCatalog catalog,
  }) {
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;
    final days = <KeyDay>[
      for (final e in ekadashis)
        if (inMonth(e.date))
          KeyDay(
            id: e.occurrenceUid,
            key: null,
            date: DateTime.utc(e.date.year, e.date.month, e.date.day),
            title: e.name,
            categories: const [SearchCategory.ekadashi],
            requiresPremium: false,
          ),
    ];
    final seen = <String>{};
    for (final dated in observances) {
      if (!inMonth(dated.date) ||
          catalog.excludedEngineIds.contains(dated.observance.id)) {
        continue;
      }
      final entry = catalog.observance(
        dated.observance.id,
        dated.observance.name,
      );
      if (entry == null) continue;
      final id = '${entry.key}:${_iso(dated.date)}';
      if (!seen.add(id)) continue;
      days.add(
        KeyDay(
          id: id,
          key: entry.key,
          date: DateTime.utc(dated.date.year, dated.date.month, dated.date.day),
          title: entry.name(language),
          categories: entry.categories,
          requiresPremium: true,
        ),
      );
    }
    int rank(KeyDay d) => d.categories.contains(SearchCategory.ekadashi)
        ? 0
        : d.categories.contains(SearchCategory.festival)
        ? 1
        : 2;
    final indexed = days.indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.date.compareTo(b.$2.date);
        if (byDate != 0) return byDate;
        final byRank = rank(a.$2).compareTo(rank(b.$2));
        if (byRank != 0) return byRank;
        return a.$1.compareTo(b.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  static List<KeyDay> filter(List<KeyDay> days, SearchCategory? category) =>
      category == null
      ? days
      : days.where((d) => d.categories.contains(category)).toList();
}
