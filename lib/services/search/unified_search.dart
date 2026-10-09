import 'package:characters/characters.dart';

import 'search_catalog.dart';
import 'search_text.dart';

/// One searchable thing: an Ekadashi, a Panchang observance on a date, a
/// calendar entry or an app screen.
class SearchItem {
  const SearchItem({
    required this.id,
    required this.target,
    required this.categories,
    required this.title,
    required this.titleEnglish,
    required this.names,
    required this.text,
    required this.date,
    required this.requiresPremium,
  });

  /// `<occurrence uid>`, `observance:<key>:<date>`, `entry:<id>` or `screen:<key>`.
  final String id;
  final SearchTarget target;
  final List<SearchCategory> categories;

  /// The title in the app language.
  final String title;
  final String titleEnglish;

  /// Every name that counts as a title match: all languages and aliases.
  final List<String> names;

  /// Other searchable text (descriptions, notes, calendar names).
  final String text;

  /// The civil date (UTC midnight), or null for screens.
  final DateTime? date;

  /// Panchang observances belong to the Premium festival finder.
  final bool requiresPremium;
}

/// A query split into words, with a year and a type taken out of it.
class ParsedSearchQuery {
  const ParsedSearchQuery(this.tokens, this.year, this.category);
  final List<String> tokens;
  final int? year;
  final SearchCategory? category;

  /// Nothing left to match: list everything the filters allow.
  bool get isListing => tokens.isEmpty;
}

class SearchQueryParser {
  const SearchQueryParser._();

  static final _year = RegExp(r'^[0-9]{4}$');

  /// A four-digit year becomes the year filter and a type word ("amavasai",
  /// "festivals", "शिवरात्रि") the type filter. A chip the user chose wins
  /// over a word in the query. A type word alone lists that type; with other
  /// words it filters and still has to match.
  static ParsedSearchQuery parse(
    String raw,
    SearchCatalog catalog, {
    SearchCategory? category,
    int? year,
  }) {
    var parsedYear = year;
    final words = <String>[];
    for (final token in SearchText.normalize(raw).split(' ')) {
      if (token.isEmpty) continue;
      if (_year.hasMatch(token)) {
        final value = int.parse(token);
        if (value >= 1900 && value <= 2200) {
          if (year == null) parsedYear = value;
          continue;
        }
      }
      words.add(token);
    }
    if (category != null) {
      return ParsedSearchQuery(words, parsedYear, category);
    }
    SearchCategory? named;
    var typeWords = 0;
    for (final word in words) {
      final found = catalog.categoryNamed(word);
      if (found != null) {
        named ??= found;
        typeWords++;
      }
    }
    final onlyTypeWords = named != null && typeWords == words.length;
    return ParsedSearchQuery(
      onlyTypeWords ? const [] : words,
      parsedYear,
      named,
    );
  }
}

class _Prepared {
  _Prepared(this.item, this.names, this.nameTokens, this.words);
  final SearchItem item;
  final List<String> names;
  final List<List<String>> nameTokens;
  final List<String> words;
}

/// On-device search over the whole app (the Swift `UnifiedSearch`; both
/// apps run test/fixtures/search/search_golden.json). Every query word must
/// match a word of the item (exactly, as a prefix, with a typo, or as
/// in-order letters), then results rank by how well a name matches:
///
/// 1000 exact name · 900 name starts with the query and a space · 800 name
/// prefix · 600 name contains the query · 450 every word starts a name word
/// · 300 − 10 per typo when every word matches a name word · 200 body words
/// · 100 − 10 per typo in body words · 50 in-order letters ("ekdsh").
///
/// Equal scores show upcoming dates first (soonest first), then undated
/// screens, then past dates (most recent first).
class UnifiedSearch {
  UnifiedSearch(this.items, this.catalog)
    : _prepared = [for (final item in items) _prepare(item, catalog)];

  final List<SearchItem> items;
  final SearchCatalog catalog;
  final List<_Prepared> _prepared;

  static _Prepared _prepare(SearchItem item, SearchCatalog catalog) {
    final names = [
      for (final name in item.names)
        if (SearchText.normalize(name).isNotEmpty) SearchText.normalize(name),
    ];
    final words = <String>[];
    final seen = <String>{};
    final typeWords = [
      for (final category in item.categories) ...catalog.keywords(category),
    ];
    for (final word in [
      ...names,
      SearchText.normalize(item.text),
      ...typeWords,
    ].join(' ').split(' ')) {
      if (seen.add(word)) words.add(word);
    }
    return _Prepared(item, names, [
      for (final name in names) name.split(' '),
    ], words);
  }

  /// The data years, for the year filter.
  List<int> get years =>
      ({for (final item in items) ?item.date?.year}).toList()..sort();

  List<SearchItem> search(
    String raw, {
    SearchCategory? category,
    int? year,
    required DateTime today,
    int limit = 300,
  }) {
    final query = SearchQueryParser.parse(
      raw,
      catalog,
      category: category,
      year: year,
    );
    bool allowed(SearchItem item) {
      if (query.year != null && item.date?.year != query.year) return false;
      if (query.category != null && !item.categories.contains(query.category)) {
        return false;
      }
      return true;
    }

    final day = DateTime.utc(today.year, today.month, today.day);
    if (query.isListing) {
      if (query.year == null && query.category == null) return const [];
      final listed = [
        for (final entry in _prepared)
          if (allowed(entry.item) &&
              !entry.item.categories.contains(SearchCategory.screen))
            entry.item,
      ]..sort((a, b) => _compare(a, b, day));
      return listed.take(limit).toList();
    }
    final phrase = query.tokens.join(' ');
    final scored = <(SearchItem, double)>[];
    for (final entry in _prepared) {
      if (!allowed(entry.item)) continue;
      final value = _score(entry, phrase, query.tokens);
      if (value != null) scored.add((entry.item, value));
    }
    scored.sort(
      (a, b) => a.$2 != b.$2 ? b.$2.compareTo(a.$2) : _compare(a.$1, b.$1, day),
    );
    return [for (final s in scored.take(limit)) s.$1];
  }

  /// Titles starting with (then containing) the typed text, in the app language.
  List<String> suggestions(String raw, {int limit = 5}) {
    final typed = SearchText.normalize(raw);
    if (typed.isEmpty) return const [];
    final result = <String>[];
    for (var pass = 0; pass < 2; pass++) {
      for (final entry in _prepared) {
        final title = SearchText.normalize(entry.item.title);
        final hit = pass == 0
            ? entry.names.any((n) => n.startsWith(typed))
            : title.contains(typed);
        if (hit && !result.contains(entry.item.title)) {
          result.add(entry.item.title);
        }
        if (result.length == limit) return result;
      }
    }
    return result;
  }

  double? _score(_Prepared entry, String phrase, List<String> tokens) {
    var edits = 0;
    var looseLetters = false;
    for (final token in tokens) {
      int? best;
      for (final word in entry.words) {
        final d = SearchText.tokenDistance(token, word);
        if (d != null && (best == null || d < best)) best = d;
      }
      if (best != null) {
        edits += best;
      } else if (token.characters.length >= 3 &&
          entry.words.any(
            (w) =>
                w.isNotEmpty &&
                w.characters.first == token.characters.first &&
                SearchText.isSubsequence(token, w),
          )) {
        looseLetters = true;
      } else {
        return null;
      }
    }
    if (looseLetters) return 50;
    var best = 0.0;
    for (var i = 0; i < entry.names.length; i++) {
      final name = entry.names[i], nameTokens = entry.nameTokens[i];
      double value;
      if (name == phrase) {
        value = 1000;
      } else if (name.startsWith('$phrase ')) {
        value = 900;
      } else if (name.startsWith(phrase)) {
        value = 800;
      } else if (name.contains(phrase)) {
        value = 600;
      } else if (tokens.every(
        (q) => nameTokens.any((t) => SearchText.tokenDistance(q, t) == 0),
      )) {
        value = 450;
      } else if (tokens.every(
        (q) => nameTokens.any((t) => SearchText.tokenDistance(q, t) != null),
      )) {
        value = 300 - edits * 10;
      } else {
        value = 0;
      }
      if (value > best) best = value;
    }
    if (best == 0) best = edits == 0 ? 200 : 100 - edits * 10.0;
    return best;
  }

  /// Upcoming first (soonest first), then undated, then past (latest first).
  static int _compare(SearchItem a, SearchItem b, DateTime today) {
    int bucket(DateTime? date) =>
        date == null ? 1 : (date.isBefore(today) ? 2 : 0);
    final ba = bucket(a.date), bb = bucket(b.date);
    if (ba != bb) return ba.compareTo(bb);
    final da = a.date, db = b.date;
    if (da != null && db != null && da != db) {
      return ba == 0 ? da.compareTo(db) : db.compareTo(da);
    }
    return a.id.compareTo(b.id);
  }
}
