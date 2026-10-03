import 'search_content_type.dart';
import 'search_index_entry.dart';

/// Unified SearchResult model representing a ranked match presented to the user.
class SearchResult {
  final String id;
  final SearchContentType contentType;
  final String title;
  final String subtitle;
  final String? highlight;
  final String? imageReference;
  final String? date;
  final String language;
  final bool isDownloaded;
  final bool isOnlineOnly;
  final double relevanceScore;
  final String navigationTarget;
  final Map<String, dynamic> sourceData;

  const SearchResult({
    required this.id,
    required this.contentType,
    required this.title,
    required this.subtitle,
    this.highlight,
    this.imageReference,
    this.date,
    this.language = 'en',
    this.isDownloaded = true,
    this.isOnlineOnly = false,
    this.relevanceScore = 0.0,
    required this.navigationTarget,
    this.sourceData = const {},
  });

  factory SearchResult.fromIndexEntry(
    SearchIndexEntry entry, {
    required double score,
    String? highlightSnippet,
  }) {
    return SearchResult(
      id: entry.id,
      contentType: entry.contentType,
      title: entry.title,
      subtitle: entry.description,
      highlight: highlightSnippet,
      date: entry.date,
      language: entry.language,
      isDownloaded: entry.isDownloaded,
      isOnlineOnly: entry.isOnlineOnly,
      relevanceScore: score,
      navigationTarget: entry.navigationTarget,
      sourceData: entry.metadata,
    );
  }

  SearchResult copyWith({
    String? id,
    SearchContentType? contentType,
    String? title,
    String? subtitle,
    String? highlight,
    String? imageReference,
    String? date,
    String? language,
    bool? isDownloaded,
    bool? isOnlineOnly,
    double? relevanceScore,
    String? navigationTarget,
    Map<String, dynamic>? sourceData,
  }) {
    return SearchResult(
      id: id ?? this.id,
      contentType: contentType ?? this.contentType,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      highlight: highlight ?? this.highlight,
      imageReference: imageReference ?? this.imageReference,
      date: date ?? this.date,
      language: language ?? this.language,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isOnlineOnly: isOnlineOnly ?? this.isOnlineOnly,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      navigationTarget: navigationTarget ?? this.navigationTarget,
      sourceData: sourceData ?? this.sourceData,
    );
  }
}
