import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/wisdom_question.dart';

/// Loads the question dataset from the bundled JSON asset and provides
/// deterministic daily question selection with balanced category rotation.
class WisdomQuestionService {
  WisdomQuestionService({this.assetPath = 'assets/wisdom/ekadashi_wisdom.json'});

  static final instance = WisdomQuestionService();

  final String assetPath;
  List<Map<String, dynamic>>? _rawQuestions;

  /// The four question categories in rotation order.
  static const categories = ['ekadashi', 'bhagavad_gita', 'mahabharata', 'ramayana'];

  /// Load the raw question data from the asset bundle.
  Future<void> load() async {
    if (_rawQuestions != null) return;
    final jsonStr = await rootBundle.loadString(assetPath);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    _rawQuestions = List<Map<String, dynamic>>.from(
      data['questions'] as List,
    );
  }

  /// Inject pre-loaded data (for testing without asset bundle).
  void loadFromData(List<Map<String, dynamic>> questions) {
    _rawQuestions = questions;
  }

  /// All question IDs in the dataset.
  List<String> get allQuestionIds =>
      _rawQuestions?.map((q) => q['question_id'] as String).toList() ?? [];

  /// Total number of questions in the dataset.
  int get questionCount => _rawQuestions?.length ?? 0;

  /// Get a question by ID for a specific language.
  WisdomQuestion? getQuestion(String questionId, String languageCode) {
    final raw = _rawQuestions?.firstWhere(
      (q) => q['question_id'] == questionId,
      orElse: () => <String, dynamic>{},
    );
    if (raw == null || raw.isEmpty) return null;
    return WisdomQuestion.fromJson(raw, languageCode);
  }

  /// Deterministic Question of the Day selection.
  ///
  /// The same date always returns the same question ID. The selection
  /// cycles through categories to ensure balanced coverage, and uses
  /// a hash to pick within each category. [answeredIds] lets us skip
  /// questions the user has already answered, falling back to a repeat
  /// only when the entire pool is exhausted.
  String? dailyQuestionId(DateTime localDate, {Set<String> answeredIds = const {}}) {
    if (_rawQuestions == null || _rawQuestions!.isEmpty) return null;

    // Day number since epoch for deterministic rotation.
    final dayNumber = localDate.difference(DateTime(2026, 1, 1)).inDays;

    // Pick the category for today (rotate through 4 categories).
    final categoryIndex = dayNumber % categories.length;
    final category = categories[categoryIndex];

    // Questions in this category.
    final categoryQuestions = _rawQuestions!
        .where((q) => q['category'] == category)
        .toList();

    if (categoryQuestions.isEmpty) {
      // Fallback to the full pool.
      return _pickFromPool(_rawQuestions!, dayNumber, answeredIds);
    }

    // Try unanswered questions in this category first.
    final unanswered = categoryQuestions
        .where((q) => !answeredIds.contains(q['question_id'] as String))
        .toList();

    if (unanswered.isNotEmpty) {
      final index = dayNumber ~/ categories.length % unanswered.length;
      return unanswered[index]['question_id'] as String;
    }

    // All in this category answered — try unanswered from any category.
    final allUnanswered = _rawQuestions!
        .where((q) => !answeredIds.contains(q['question_id'] as String))
        .toList();

    if (allUnanswered.isNotEmpty) {
      return _pickFromPool(allUnanswered, dayNumber, const {});
    }

    // All questions answered — allow repeats, pick from category.
    final index = dayNumber ~/ categories.length % categoryQuestions.length;
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
    final index = dayNumber % effectivePool.length;
    return effectivePool[index]['question_id'] as String;
  }

  /// Pick the next question for "Continue Learning" (not the daily question).
  ///
  /// Returns the next unanswered question, cycling through categories,
  /// or null if everything has been answered.
  String? nextQuestion({
    required Set<String> answeredIds,
    required String excludeQuestionId,
  }) {
    if (_rawQuestions == null || _rawQuestions!.isEmpty) return null;

    final unanswered = _rawQuestions!
        .where((q) =>
            q['question_id'] != excludeQuestionId &&
            !answeredIds.contains(q['question_id'] as String))
        .toList();

    if (unanswered.isEmpty) return null;
    return unanswered.first['question_id'] as String;
  }
}

