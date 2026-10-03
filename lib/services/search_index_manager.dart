import 'search_matching.dart';
import 'package:flutter/foundation.dart';
import '../models/search_content_type.dart';
import '../models/search_index_entry.dart';
import '../models/search_result.dart';
import 'content_catalog_service.dart';
import 'ekadashi_service.dart';

/// Centralized manager for building, maintaining, and searching the global search index (Module 19).
class SearchIndexManager extends ChangeNotifier {
  static const int searchIndexVersion = 1;

  static final SearchIndexManager _instance = SearchIndexManager._internal();
  factory SearchIndexManager() => _instance;
  SearchIndexManager._internal();

  final ContentCatalogService _catalogService = ContentCatalogService();

  List<SearchIndexEntry> _index = [];
  int _generation = 0;
  bool _isIndexReady = false;
  bool _isIndexing = false;
  String _currentLanguage = 'en';

  // Manual offline toggle for testing or forced offline mode (defaults to false)
  bool _isForcedOffline = false;

  bool get isIndexReady => _isIndexReady;
  bool get isIndexing => _isIndexing;
  bool get isForcedOffline => _isForcedOffline;
  bool get isOffline => _isForcedOffline;
  List<SearchIndexEntry> get allEntries => List.unmodifiable(_index);

  void setForcedOffline(bool value) {
    if (_isForcedOffline != value) {
      _isForcedOffline = value;
      notifyListeners();
    }
  }

  /// Initialize and build the search index from existing application data
  Future<void> initializeIndex({
    required List<EkadashiDate> ekadashiList,
    String language = 'en',
  }) async {
    final generation = ++_generation;
    _isIndexing = true;
    _currentLanguage = language;
    notifyListeners();

    try {
      final entries = await _catalogService.buildAllCatalogEntries(
        ekadashiList: ekadashiList,
        currentLanguage: language,
      );
      if (generation != _generation) return;
      _index = entries;
      _isIndexReady = true;
    } catch (e) {
      debugPrint('⚠️ SearchIndexManager indexing error: $e');
    } finally {
      if (generation == _generation) {
        _isIndexing = false;
        notifyListeners();
      }
    }
  }

  /// Convenience alias for initializing index
  Future<void> buildIndexFromEkadashis(
    List<EkadashiDate> ekadashis, {
    String languageCode = 'en',
  }) async {
    await initializeIndex(ekadashiList: ekadashis, language: languageCode);
  }

  /// Download an online-only item and incrementally update the search index (EC2-FR-081)
  Future<bool> downloadItem(
    String id, {
    List<EkadashiDate>? ekadashiList,
  }) async {
    final success = await _catalogService.downloadItem(id);
    if (success) {
      // Incremental update in current index
      final idx = _index.indexWhere((entry) => entry.id == id);
      if (idx != -1) {
        _index[idx] = _index[idx].copyWith(
          isDownloaded: true,
          isOnlineOnly: false,
        );
        notifyListeners();
      } else if (ekadashiList != null) {
        await initializeIndex(
          ekadashiList: ekadashiList,
          language: _currentLanguage,
        );
      }
    }
    return success;
  }

  /// Convenience alias for downloading item
  Future<bool> downloadContent(String id) async {
    return downloadItem(id);
  }

  /// Execute search query across all indexed content with relevance ranking and filtering
  List<SearchResult> search(
    String query, {
    SearchContentType contentType = SearchContentType.all,
    SearchContentType? filter,
    String? languageCode,
    int? year,
    bool? isOfflineOverride,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final activeFilter = filter ?? contentType;
    final normalizedQuery = normalizeString(trimmed);
    final queryTokens = normalizedQuery
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    if (queryTokens.isEmpty) return [];

    final isOffline = isOfflineOverride ?? _isForcedOffline;

    final List<SearchResult> results = [];

    for (final entry in _index) {
      if (languageCode != null && entry.language != languageCode) continue;
      if (year != null &&
          entry.date != null &&
          !entry.date!.startsWith('$year-')) {
        continue;
      }
      // 1. Content Type Filter (EC2-FR-080)
      if (activeFilter != SearchContentType.all &&
          entry.contentType != activeFilter) {
        continue;
      }

      // 2. Offline Enforcement (EC2-FR-081):
      // If offline, only locally downloaded content shall appear.
      if (isOffline && (!entry.isDownloaded || entry.isOnlineOnly)) {
        continue;
      }

      // 3. Relevance Scoring
      final score = _calculateRelevance(entry, normalizedQuery, queryTokens);
      if (score > 0) {
        final highlight = _extractHighlightSnippet(entry, trimmed);
        results.add(
          SearchResult.fromIndexEntry(
            entry,
            score: score,
            highlightSnippet: highlight,
          ),
        );
      }
    }

    // 4. Sort by relevance descending
    results.sort((a, b) {
      final score = b.relevanceScore.compareTo(a.relevanceScore);
      return score != 0 ? score : a.id.compareTo(b.id);
    });

    return results;
  }

  /// Generate live suggestions based on current query prefix and keywords
  List<String> getSuggestions(String query, {int limit = 5}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final normalized = normalizeString(trimmed);
    final Set<String> suggestions = {};

    // 1. Check title prefixes
    for (final entry in _index) {
      if (entry.language != _currentLanguage) continue;
      if (entry.normalizedTitle.startsWith(normalized)) {
        suggestions.add(entry.title);
      }
      if (suggestions.length >= limit) break;
    }

    // 2. Check title contains
    if (suggestions.length < limit) {
      for (final entry in _index) {
        if (entry.language != _currentLanguage) continue;
        if (entry.normalizedTitle.contains(normalized)) {
          suggestions.add(entry.title);
        }
        if (suggestions.length >= limit) break;
      }
    }

    // 3. Check keywords
    if (suggestions.length < limit) {
      for (final entry in _index) {
        if (entry.language != _currentLanguage) continue;
        for (final kw in entry.keywords) {
          if (normalizeString(kw).startsWith(normalized)) {
            suggestions.add(kw[0].toUpperCase() + kw.substring(1));
          }
          if (suggestions.length >= limit) break;
        }
        if (suggestions.length >= limit) break;
      }
    }

    return suggestions.take(limit).toList();
  }

  /// Alias for live search suggestions
  List<String> getLiveSuggestions(String query, {int limit = 5}) =>
      getSuggestions(query, limit: limit);

  /// Relevance Calculation Algorithm (Section 25)
  double _calculateRelevance(
    SearchIndexEntry entry,
    String normalizedQuery,
    List<String> queryTokens,
  ) {
    if (queryTokens.isEmpty) return 0;
    final title = normalizeString(entry.title);
    final titleTokens = title.split(' ');
    final words = normalizeString(
      '${entry.title} ${entry.normalizedText} ${entry.keywords.join(' ')} ${entry.tags.join(' ')}',
    ).split(' ').toSet();
    var edits = 0;
    for (final token in queryTokens) {
      final distances = words
          .map((word) => searchTokenDistance(token, word))
          .whereType<int>()
          .toList();
      if (distances.isEmpty) return 0; // Every query token must match.
      edits += distances.reduce((a, b) => a < b ? a : b);
    }
    double score;
    if (title == normalizedQuery) {
      score = 1000;
    } else if (title.startsWith('$normalizedQuery ')) {
      score = 900;
    } else if (title.startsWith(normalizedQuery)) {
      score = 800;
    } else if (title.contains(normalizedQuery)) {
      score = 600;
    } else if (queryTokens.every(
      (q) => titleTokens.any((t) => searchTokenDistance(q, t) == 0),
    )) {
      score = 450;
    } else if (queryTokens.every(
      (q) => titleTokens.any((t) => searchTokenDistance(q, t) != null),
    )) {
      score = 300 - edits * 10.0;
    } else if (edits == 0) {
      score = 200;
    } else {
      score = 100 - edits * 10.0;
    }
    if (entry.contentType == SearchContentType.ekadashi) score += 5;
    if (entry.isDownloaded && !entry.isOnlineOnly) score += 2;
    return score;
  }

  /// Extract snippet around matched query for highlighting (Section 24)
  String _extractHighlightSnippet(SearchIndexEntry entry, String rawQuery) {
    final lowerDesc = entry.description.toLowerCase();
    final lowerQuery = rawQuery.toLowerCase();
    final idx = lowerDesc.indexOf(lowerQuery);

    if (idx != -1) {
      final start = (idx - 30).clamp(0, entry.description.length);
      final end = (idx + rawQuery.length + 50).clamp(
        0,
        entry.description.length,
      );
      final snippet = entry.description.substring(start, end).trim();
      return (start > 0 ? '...' : '') +
          snippet +
          (end < entry.description.length ? '...' : '');
    }

    return entry.description.length > 90
        ? '${entry.description.substring(0, 90)}...'
        : entry.description;
  }

  /// Public string normalization helper
  static String normalizeString(String input) {
    return normalizeSearchText(input);
  }
}
