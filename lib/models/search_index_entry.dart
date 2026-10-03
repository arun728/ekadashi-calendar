import 'search_content_type.dart';

/// Lightweight search index entry representing an indexed content record.
class SearchIndexEntry {
  final String id;
  final SearchContentType contentType;
  final String title;
  final String normalizedTitle;
  final String description;
  final String normalizedText;
  final List<String> keywords;
  final String language;
  final String? date;
  final List<String> tags;
  final String sourceId;
  final bool isDownloaded;
  final bool isOnlineOnly;
  final String updatedAtUTC;
  final String navigationTarget;
  final Map<String, dynamic> metadata;

  const SearchIndexEntry({
    required this.id,
    required this.contentType,
    required this.title,
    required this.normalizedTitle,
    required this.description,
    required this.normalizedText,
    required this.keywords,
    this.language = 'en',
    this.date,
    this.tags = const [],
    required this.sourceId,
    this.isDownloaded = true,
    this.isOnlineOnly = false,
    required this.updatedAtUTC,
    required this.navigationTarget,
    this.metadata = const {},
  });

  SearchIndexEntry copyWith({
    String? id,
    SearchContentType? contentType,
    String? title,
    String? normalizedTitle,
    String? description,
    String? normalizedText,
    List<String>? keywords,
    String? language,
    String? date,
    List<String>? tags,
    String? sourceId,
    bool? isDownloaded,
    bool? isOnlineOnly,
    String? updatedAtUTC,
    String? navigationTarget,
    Map<String, dynamic>? metadata,
  }) {
    return SearchIndexEntry(
      id: id ?? this.id,
      contentType: contentType ?? this.contentType,
      title: title ?? this.title,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      description: description ?? this.description,
      normalizedText: normalizedText ?? this.normalizedText,
      keywords: keywords ?? this.keywords,
      language: language ?? this.language,
      date: date ?? this.date,
      tags: tags ?? this.tags,
      sourceId: sourceId ?? this.sourceId,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isOnlineOnly: isOnlineOnly ?? this.isOnlineOnly,
      updatedAtUTC: updatedAtUTC ?? this.updatedAtUTC,
      navigationTarget: navigationTarget ?? this.navigationTarget,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentType': contentType.name,
      'title': title,
      'normalizedTitle': normalizedTitle,
      'description': description,
      'normalizedText': normalizedText,
      'keywords': keywords,
      'language': language,
      'date': date,
      'tags': tags,
      'sourceId': sourceId,
      'isDownloaded': isDownloaded,
      'isOnlineOnly': isOnlineOnly,
      'updatedAtUTC': updatedAtUTC,
      'navigationTarget': navigationTarget,
      'metadata': metadata,
    };
  }

  factory SearchIndexEntry.fromJson(Map<String, dynamic> json) {
    return SearchIndexEntry(
      id: json['id'] as String,
      contentType: SearchContentType.fromString(json['contentType'] as String?),
      title: json['title'] as String? ?? '',
      normalizedTitle: json['normalizedTitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      normalizedText: json['normalizedText'] as String? ?? '',
      keywords:
          (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      language: json['language'] as String? ?? 'en',
      date: json['date'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      sourceId: json['sourceId'] as String? ?? '',
      isDownloaded: json['isDownloaded'] as bool? ?? true,
      isOnlineOnly: json['isOnlineOnly'] as bool? ?? false,
      updatedAtUTC: json['updatedAtUTC'] as String? ?? '',
      navigationTarget: json['navigationTarget'] as String? ?? '',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}
