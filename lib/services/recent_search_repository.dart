import 'package:shared_preferences/shared_preferences.dart';

/// Repository for managing on-device, privacy-preserving recent search queries (EC2-FR-082).
class RecentSearchRepository {
  static const String _recentSearchesKey = 'ec2_recent_searches_list';
  static const int maxRecentSearches = 10;

  static final RecentSearchRepository _instance = RecentSearchRepository._internal();
  factory RecentSearchRepository() => _instance;
  RecentSearchRepository._internal();

  /// Retrieve list of recent searches from local SharedPreferences.
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? [];
      return sanitizeHistory(list);
    } catch (_) {
      return [];
    }
  }

  /// Sanitizes history to remove obvious intermediate prefixes (e.g. 'p', 'pa', 'par')
  /// while preserving genuine search entries.
  static List<String> sanitizeHistory(List<String> rawList) {
    if (rawList.isEmpty) return [];
    final sanitized = <String>[];
    for (int i = 0; i < rawList.length; i++) {
      final current = rawList[i].trim();
      if (current.isEmpty) continue;

      // Check if current is a short intermediate prefix (<= 3 chars) of another longer entry
      bool isIntermediatePrefix = false;
      for (int j = 0; j < rawList.length; j++) {
        if (i == j) continue;
        final other = rawList[j].trim();
        if (other.toLowerCase().startsWith(current.toLowerCase()) &&
            current.length <= 3 &&
            other.length > current.length) {
          isIntermediatePrefix = true;
          break;
        }
      }
      if (!isIntermediatePrefix && !sanitized.any((s) => s.toLowerCase() == current.toLowerCase())) {
        sanitized.add(current);
      }
    }
    return sanitized;
  }

  /// Add a search term to recent history.
  /// If already present, moves the term to the top.
  /// Automatically caps the list to [maxRecentSearches].
  Future<void> addSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList(_recentSearchesKey) ?? [];

      // Deduplicate: remove existing case-insensitive match
      list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());

      // Clean up any existing accidental intermediate progressive prefixes of this search
      list.removeWhere((item) {
        final itemLower = item.toLowerCase();
        final trimmedLower = trimmed.toLowerCase();
        return trimmedLower.startsWith(itemLower) && itemLower.length <= 3 && itemLower.length < trimmedLower.length;
      });

      // Insert at top
      list.insert(0, trimmed);

      // Enforce limit
      if (list.length > maxRecentSearches) {
        list = list.sublist(0, maxRecentSearches);
      }

      await prefs.setStringList(_recentSearchesKey, list);
    } catch (_) {}
  }

  /// Delete a single search query from recent history.
  Future<void> deleteSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList(_recentSearchesKey) ?? [];
      list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
      await prefs.setStringList(_recentSearchesKey, list);
    } catch (_) {}
  }

  /// Clear all recent searches.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (_) {}
  }
}
