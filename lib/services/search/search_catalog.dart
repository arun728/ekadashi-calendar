import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'search_text.dart';

/// What a search result is; also the filter chips (all but [screen]).
enum SearchCategory {
  ekadashi('ekadashi', 0xFF00A19B),
  festival('festival', 0xFFF97316),
  amavasya('amavasya', 0xFF6366F1),
  purnima('purnima', 0xFFEAB308),
  shivaratri('shivaratri', 0xFF8B5CF6),
  chaturthi('chaturthi', 0xFFEC4899),
  pradosham('pradosham', 0xFFF59E0B),
  navaratri('navaratri', 0xFFEF4444),
  sankranti('sankranti', 0xFFF59E0B),
  jayanti('jayanti', 0xFF0EA5E9),
  myCalendar('my_calendar', 0xFF10B981),
  screen('screen', 0xFF64748B);

  const SearchCategory(this.raw, this.color);
  final String raw;

  /// ARGB colour of the badge.
  final int color;

  /// The filter chips, in display order after "All".
  static List<SearchCategory> get filters =>
      values.where((c) => c != screen).toList();

  /// The search pages, in chip order: All (null), then each type.
  static List<SearchCategory?> get pages => [null, ...filters];

  String get localizationKey => 'search_filter_$raw';

  static SearchCategory? parse(String raw) {
    for (final c in values) {
      if (c.raw == raw) return c;
    }
    return null;
  }
}

enum SearchTargetKind {
  ekadashi,
  observance,
  entry,
  tab,
  paywall,
  widgetPreview,
}

/// Where a search result leads.
class SearchTarget {
  const SearchTarget._(this.kind, {this.id, this.date, this.tab});
  const SearchTarget.ekadashi(String occurrenceUid)
    : this._(SearchTargetKind.ekadashi, id: occurrenceUid);
  const SearchTarget.observance(String key, DateTime date)
    : this._(SearchTargetKind.observance, id: key, date: date);
  const SearchTarget.entry(String id, DateTime date)
    : this._(SearchTargetKind.entry, id: id, date: date);

  /// [tab] is the bottom tab index: 0 Today, 1 Calendar, 2 Journey,
  /// 3 Panchang, 4 Settings.
  const SearchTarget.tab(int tab) : this._(SearchTargetKind.tab, tab: tab);
  static const paywall = SearchTarget._(SearchTargetKind.paywall);
  static const widgetPreview = SearchTarget._(SearchTargetKind.widgetPreview);

  final SearchTargetKind kind;
  final String? id;
  final DateTime? date;
  final int? tab;

  @override
  bool operator ==(Object other) =>
      other is SearchTarget &&
      other.kind == kind &&
      other.id == id &&
      other.date == date &&
      other.tab == tab;

  @override
  int get hashCode => Object.hash(kind, id, date, tab);
}

class CatalogObservance {
  const CatalogObservance({
    required this.key,
    required this.engineId,
    required this.engineName,
    required this.categories,
    required this.names,
    required this.aliases,
  });
  final String key;
  final String engineId;

  /// Set when one engine id carries several observances (the Bhadrapada
  /// Vinayaka Chaturthi is Ganesh Chaturthi).
  final String? engineName;
  final List<SearchCategory> categories;
  final Map<String, String> names;
  final List<String> aliases;

  String name(String language) => names[language] ?? names['en'] ?? key;
}

class CatalogScreen {
  const CatalogScreen({
    required this.key,
    required this.titleKey,
    required this.target,
    required this.aliases,
  });
  final String key;
  final String titleKey;
  final SearchTarget target;
  final List<String> aliases;
}

/// The shared search catalog (assets/search/search_catalog.json): Panchang
/// observances with names in every language and aliases, the words that act
/// as type filters, and app screens. The iOS app reads the same file.
class SearchCatalog {
  SearchCatalog._(
    this.observances,
    this.screens,
    this.excludedEngineIds,
    this._keywords,
  );

  static const asset = 'assets/search/search_catalog.json';
  static SearchCatalog? _bundled;

  /// The bundled catalog, once [load] has run.
  static SearchCatalog get bundled =>
      _bundled ?? (throw StateError('SearchCatalog.load() has not run'));

  /// Decoded here rather than with `loadString`, which hands large assets to
  /// another isolate (that never finishes under widget tests' fake async).
  static Future<SearchCatalog> load() async {
    final data = await rootBundle.load(asset);
    return _bundled ??= SearchCatalog.parse(
      utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );
  }

  final List<CatalogObservance> observances;
  final List<CatalogScreen> screens;
  final Set<String> excludedEngineIds;
  final Map<SearchCategory, List<String>> _keywords;

  factory SearchCatalog.parse(String text) {
    final root = jsonDecode(text) as Map<String, dynamic>;
    SearchCategory category(String raw) =>
        SearchCategory.parse(raw) ??
        (throw FormatException('search catalog category $raw'));
    final keywords = <SearchCategory, List<String>>{
      for (final entry
          in (root['categories'] as Map<String, dynamic>? ?? {}).entries)
        category(entry.key): [
          for (final word in entry.value as List) SearchText.normalize('$word'),
        ],
    };
    final observances = [
      for (final row in root['observances'] as List? ?? const [])
        CatalogObservance(
          key: row['key'] as String? ?? '',
          engineId: (row['engine'] as Map?)?['id'] as String? ?? '',
          engineName: (row['engine'] as Map?)?['name'] as String?,
          categories: [
            for (final raw in row['categories'] as List? ?? const [])
              category('$raw'),
          ],
          names: Map<String, String>.from(row['names'] as Map? ?? const {}),
          aliases: List<String>.from(row['aliases'] as List? ?? const []),
        ),
    ];
    final screens = [
      for (final row in root['screens'] as List? ?? const [])
        CatalogScreen(
          key: row['key'] as String? ?? '',
          titleKey: row['titleKey'] as String? ?? '',
          target:
              _target(row['target'] as String? ?? '') ??
              (throw FormatException('screen target ${row['target']}')),
          aliases: List<String>.from(row['aliases'] as List? ?? const []),
        ),
    ];
    return SearchCatalog._(
      observances,
      screens,
      Set<String>.from(root['excludedEngineIds'] as List? ?? const []),
      keywords,
    );
  }

  static SearchTarget? _target(String raw) => switch (raw) {
    'paywall' => SearchTarget.paywall,
    'widget_preview' => SearchTarget.widgetPreview,
    'tab:today' => const SearchTarget.tab(0),
    'tab:calendar' => const SearchTarget.tab(1),
    'tab:vrat' => const SearchTarget.tab(2),
    'tab:panchang' => const SearchTarget.tab(3),
    'tab:settings' => const SearchTarget.tab(4),
    _ => null,
  };

  /// Normalized words that name [category] in any language.
  List<String> keywords(SearchCategory category) =>
      _keywords[category] ?? const [];

  CatalogObservance? observanceByKey(String key) {
    for (final o in observances) {
      if (o.key == key) return o;
    }
    return null;
  }

  /// The catalogue entry for an engine observance, preferring one that also
  /// matches the engine's name.
  CatalogObservance? observance(String engineId, String name) {
    for (final o in observances) {
      if (o.engineId == engineId && o.engineName == name) return o;
    }
    for (final o in observances) {
      if (o.engineId == engineId && o.engineName == null) return o;
    }
    return null;
  }

  /// The category one query word names, if any: an exact type word, or the
  /// start of one (four letters or more), or a type word with a typo.
  SearchCategory? categoryNamed(String word) {
    for (final category in SearchCategory.filters) {
      if (keywords(category).contains(word)) return category;
    }
    if (word.characters.length < 4) return null;
    for (final category in SearchCategory.filters) {
      if (keywords(
        category,
      ).any((k) => SearchText.tokenDistance(word, k) != null)) {
        return category;
      }
    }
    return null;
  }
}
