library;

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wisdom_question.dart';
import 'wisdom_selection_service.dart';
import 'wisdom_eligibility_service.dart';

/// Loads the question dataset from the bundled multilingual JSON asset,
/// provides localized questions, category/difficulty labels, UI strings,
/// and manages learning sequences via [WisdomSelectionService].
class WisdomQuestionService {
  WisdomQuestionService({
    this.assetPath = 'assets/wisdom/ekadashi_wisdom_full_bank_multilingual.json',
  });

  static final instance = WisdomQuestionService();

  final String assetPath;
  List<Map<String, dynamic>>? _rawQuestions;
  Map<String, List<String>> _optionLabels = {};
  Map<String, Map<String, String>> _uiStrings = {};
  Map<String, dynamic> _labels = {};

  final WisdomSelectionService selectionService = WisdomSelectionService();
  final WisdomEligibilityService eligibilityService = const WisdomEligibilityService();

  /// The four question categories in rotation order.
  static const categories = [
    'ekadashi',
    'bhagavad_gita',
    'mahabharata',
    'ramayana',
  ];

  /// Load the question dataset and initialize the selection service.
  Future<void> load({SharedPreferences? prefs}) async {
    if (_rawQuestions != null) return;
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _parseMetadata(data);
      _rawQuestions = List<Map<String, dynamic>>.from(
        data['questions'] as List,
      );
    } catch (_) {
      // Fallback for asset loading
      _rawQuestions = [];
    }

    await selectionService.init(_rawQuestions ?? [], prefs: prefs);
  }

  /// Inject pre-loaded data (for testing without rootBundle).
  void loadFromData(
    List<Map<String, dynamic>> questions, {
    Map<String, dynamic>? metadata,
  }) {
    _rawQuestions = questions;
    if (metadata != null) {
      _parseMetadata(metadata);
    }
  }

  void _parseMetadata(Map<String, dynamic> data) {
    if (data['option_labels'] is Map) {
      final rawOpt = data['option_labels'] as Map<String, dynamic>;
      _optionLabels = rawOpt.map(
        (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      );
    }
    if (data['ui_strings'] is Map) {
      final rawUI = data['ui_strings'] as Map<String, dynamic>;
      _uiStrings = rawUI.map((key, valMap) {
        if (valMap is Map) {
          return MapEntry(
            key,
            valMap.map((lang, txt) => MapEntry(lang.toString(), txt.toString())),
          );
        }
        return MapEntry(key, <String, String>{});
      });
    }
    if (data['labels'] is Map) {
      _labels = data['labels'] as Map<String, dynamic>;
    }
  }

  /// All question IDs in the dataset.
  List<String> get allQuestionIds =>
      _rawQuestions?.map((q) => q['question_id'] as String).toList() ?? [];

  /// Total number of questions in the dataset.
  int get questionCount => _rawQuestions?.length ?? 0;

  /// Option labels mapping for all supported languages.
  Map<String, List<String>> get optionLabels => _optionLabels;

  /// Get a question by ID for a specific language.
  WisdomQuestion? getQuestion(String questionId, String languageCode) {
    final raw = _rawQuestions?.firstWhere(
      (q) => q['question_id'] == questionId,
      orElse: () => <String, dynamic>{},
    );
    if (raw == null || raw.isEmpty) return null;
    return WisdomQuestion.fromJson(
      raw,
      languageCode,
      allOptionLabels: _optionLabels,
    );
  }

  /// Localized UI string helper.
  String getUIString(String key, String languageCode, {String? fallback}) {
    final map = _uiStrings[key];
    if (map != null) {
      final val = map[languageCode] ?? map['en'];
      if (val != null && val.isNotEmpty) return val;
    }
    return fallback ?? key;
  }

  /// Localized category label.
  String categoryLabel(String category, String languageCode) {
    final catMap = _labels['category'] as Map<String, dynamic>?;
    if (catMap != null && catMap[category] is Map) {
      final localized = catMap[category] as Map<String, dynamic>;
      return localized[languageCode]?.toString() ??
          localized['en']?.toString() ??
          category;
    }
    return category;
  }

  /// Localized difficulty label.
  String difficultyLabel(String difficulty, String languageCode) {
    final diffMap = _labels['difficulty'] as Map<String, dynamic>?;
    if (diffMap != null && diffMap[difficulty] is Map) {
      final localized = diffMap[difficulty] as Map<String, dynamic>;
      return localized[languageCode]?.toString() ??
          localized['en']?.toString() ??
          difficulty;
    }
    return difficulty;
  }

  /// Deterministic Question of the Day selection.
  ///
  /// Maintained for backwards compatibility with existing callers and tests.
  String? dailyQuestionId(
    DateTime localDate, {
    Set<String> answeredIds = const {},
  }) {
    if (_rawQuestions == null || _rawQuestions!.isEmpty) return null;

    final dayNumber = localDate.difference(DateTime(2026, 1, 1)).inDays;
    final categoryIndex = dayNumber.abs() % categories.length;
    final category = categories[categoryIndex];

    final categoryQuestions = _rawQuestions!
        .where((q) => q['category'] == category)
        .toList();

    if (categoryQuestions.isEmpty) {
      return _pickFromPool(_rawQuestions!, dayNumber, answeredIds);
    }

    final unanswered = categoryQuestions
        .where((q) => !answeredIds.contains(q['question_id'] as String))
        .toList();

    if (unanswered.isNotEmpty) {
      final index = (dayNumber ~/ categories.length).abs() % unanswered.length;
      return unanswered[index]['question_id'] as String;
    }

    final allUnanswered = _rawQuestions!
        .where((q) => !answeredIds.contains(q['question_id'] as String))
        .toList();

    if (allUnanswered.isNotEmpty) {
      return _pickFromPool(allUnanswered, dayNumber, const {});
    }

    final index = (dayNumber ~/ categories.length).abs() % categoryQuestions.length;
    return categoryQuestions[index]['question_id'] as String;
  }

  String? _pickFromPool(
    List<Map<String, dynamic>> pool,
    int dayNumber,
    Set<String> answeredIds,
  ) {
    final unanswered = pool
        .where((q) => !answeredIds.contains(q['question_id'] as String))
        .toList();
    final effectivePool = unanswered.isNotEmpty ? unanswered : pool;
    if (effectivePool.isEmpty) return null;
    final index = dayNumber.abs() % effectivePool.length;
    return effectivePool[index]['question_id'] as String;
  }

  /// Pick the next question for "Continue Learning".
  String? nextQuestion({
    required Set<String> answeredIds,
    required String excludeQuestionId,
  }) {
    if (_rawQuestions == null || _rawQuestions!.isEmpty) return null;

    // Use selection service sequence if available
    for (final id in selectionService.sequence) {
      if (id != excludeQuestionId && !answeredIds.contains(id)) {
        return id;
      }
    }

    final unanswered = _rawQuestions!
        .where((q) =>
            q['question_id'] != excludeQuestionId &&
            !answeredIds.contains(q['question_id'] as String))
        .toList();

    if (unanswered.isEmpty) return null;
    return unanswered.first['question_id'] as String;
  }
}
