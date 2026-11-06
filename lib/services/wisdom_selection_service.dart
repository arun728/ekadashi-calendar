library;

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Service that builds a balanced learning sequence and manages question
/// selection, persistence, daily assignments, skipping, and exhaustion.
class WisdomSelectionService {
  WisdomSelectionService();

  static const categories = [
    'ekadashi',
    'bhagavad_gita',
    'mahabharata',
    'ramayana',
  ];

  static const _prefKeySequence = 'wisdom_learning_sequence_v2';
  static const _prefKeyIndex = 'wisdom_sequence_index_v2';
  static const _prefKeyDailyDate = 'wisdom_daily_date_v2';
  static const _prefKeyDailyQuestionId = 'wisdom_daily_question_id_v2';
  static const _prefKeyCompletedIds = 'wisdom_completed_ids_v2';
  static const _prefKeySkippedIds = 'wisdom_skipped_ids_v2';

  List<String> _sequence = [];
  int _currentIndex = 0;
  final Set<String> _completedIds = {};
  final Set<String> _skippedIds = {};
  String? _assignedDailyDate;
  String? _assignedDailyQuestionId;

  List<String> get sequence => List.unmodifiable(_sequence);
  int get currentIndex => _currentIndex;
  Set<String> get completedIds => Set.unmodifiable(_completedIds);
  Set<String> get skippedIds => Set.unmodifiable(_skippedIds);

  /// Current active question ID in the learning sequence.
  String? get currentQuestionId {
    if (_sequence.isEmpty) return null;
    if (_currentIndex >= _sequence.length) return null;
    return _sequence[_currentIndex];
  }

  /// Whether all questions in the sequence have been completed.
  bool get isExhausted {
    if (_sequence.isEmpty) return false;
    return _completedIds.containsAll(_sequence);
  }

  /// Initialize the service, restoring persisted state or building a new sequence.
  Future<void> init(
    List<Map<String, dynamic>> rawQuestions, {
    SharedPreferences? prefs,
    int? seed,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();

    // Restore completed and skipped sets
    final savedCompleted = sp.getStringList(_prefKeyCompletedIds);
    if (savedCompleted != null) {
      _completedIds.addAll(savedCompleted);
    }
    final savedSkipped = sp.getStringList(_prefKeySkippedIds);
    if (savedSkipped != null) {
      _skippedIds.addAll(savedSkipped);
    }

    _assignedDailyDate = sp.getString(_prefKeyDailyDate);
    _assignedDailyQuestionId = sp.getString(_prefKeyDailyQuestionId);

    // Restore or build sequence
    final savedSequence = sp.getStringList(_prefKeySequence);
    if (savedSequence != null && savedSequence.isNotEmpty) {
      _sequence = List<String>.from(savedSequence);
      _currentIndex = sp.getInt(_prefKeyIndex) ?? 0;
      if (_currentIndex >= _sequence.length) {
        _currentIndex = _sequence.length;
      }
    } else {
      _sequence = buildBalancedSequence(rawQuestions, seed: seed ?? 42);
      _currentIndex = 0;
      await sp.setStringList(_prefKeySequence, _sequence);
      await sp.setInt(_prefKeyIndex, _currentIndex);
    }
  }

  /// Build a balanced, shuffled learning sequence across categories,
  /// mixing difficulties and formats while avoiding concept clustering.
  List<String> buildBalancedSequence(
    List<Map<String, dynamic>> questions, {
    int? seed,
  }) {
    if (questions.isEmpty) return [];

    final random = Random(seed ?? 42);

    // Group questions by category
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final cat in categories) {
      byCategory[cat] = [];
    }

    for (final q in questions) {
      final cat = q['category'] as String? ?? 'ekadashi';
      byCategory.putIfAbsent(cat, () => []).add(q);
    }

    // Sort each category by alternating difficulty: easy, medium, hard
    for (final cat in byCategory.keys) {
      final catList = byCategory[cat]!;
      final easy = catList.where((q) => q['difficulty'] == 'easy').toList()..shuffle(random);
      final medium = catList.where((q) => q['difficulty'] == 'medium').toList()..shuffle(random);
      final hard = catList.where((q) => q['difficulty'] == 'hard').toList()..shuffle(random);

      final interleaved = <Map<String, dynamic>>[];
      while (easy.isNotEmpty || medium.isNotEmpty || hard.isNotEmpty) {
        if (easy.isNotEmpty) interleaved.add(easy.removeLast());
        if (medium.isNotEmpty) interleaved.add(medium.removeLast());
        if (hard.isNotEmpty) interleaved.add(hard.removeLast());
        if (medium.isNotEmpty) interleaved.add(medium.removeLast());
      }
      byCategory[cat] = interleaved;
    }

    // Interleave across categories in round-robin fashion
    final resultSequence = <String>[];
    String? lastConceptId;

    while (byCategory.values.any((list) => list.isNotEmpty)) {
      for (final cat in categories) {
        final list = byCategory[cat];
        if (list == null || list.isEmpty) continue;

        // Pick next question, avoiding concept repetition if possible
        int pickIndex = 0;
        if (list.length > 1 && lastConceptId != null) {
          final candidateConcept = list[0]['concept_id'] as String?;
          if (candidateConcept != null && candidateConcept == lastConceptId) {
            // Find another question with different concept in this category
            for (var i = 1; i < list.length; i++) {
              if (list[i]['concept_id'] != lastConceptId) {
                pickIndex = i;
                break;
              }
            }
          }
        }

        final picked = list.removeAt(pickIndex);
        resultSequence.add(picked['question_id'] as String);
        lastConceptId = picked['concept_id'] as String?;
      }
    }

    return resultSequence;
  }

  /// Advance to the next question in the sequence and persist state.
  Future<String?> advance({SharedPreferences? prefs}) async {
    if (_currentIndex < _sequence.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = _sequence.length;
    }

    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.setInt(_prefKeyIndex, _currentIndex);
    return currentQuestionId;
  }

  /// Mark question IDs as completed.
  void markCompleted(Set<String> questionIds) {
    _completedIds.addAll(questionIds);
  }

  /// Mark question ID as skipped and advance.
  Future<String?> skipCurrent({SharedPreferences? prefs}) async {
    final currentId = currentQuestionId;
    if (currentId != null) {
      _skippedIds.add(currentId);
      final sp = prefs ?? await SharedPreferences.getInstance();
      await sp.setStringList(_prefKeySkippedIds, _skippedIds.toList());
    }
    return advance(prefs: prefs);
  }

  /// Get or deterministically assign the stable daily Question of the Day.
  Future<String?> getOrAssignDailyQuestion(
    DateTime localDate, {
    SharedPreferences? prefs,
  }) async {
    final dateStr =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';

    final sp = prefs ?? await SharedPreferences.getInstance();

    if (_assignedDailyDate == dateStr &&
        _assignedDailyQuestionId != null &&
        _assignedDailyQuestionId!.isNotEmpty) {
      return _assignedDailyQuestionId;
    }

    if (_sequence.isEmpty) return null;

    // Deterministic selection based on days since Jan 1, 2026
    final dayNumber = localDate.difference(DateTime(2026, 1, 1)).inDays;
    final index = (dayNumber.abs()) % _sequence.length;
    final assignedId = _sequence[index];

    _assignedDailyDate = dateStr;
    _assignedDailyQuestionId = assignedId;

    await sp.setString(_prefKeyDailyDate, dateStr);
    await sp.setString(_prefKeyDailyQuestionId, assignedId);

    return assignedId;
  }

  /// Reset learning sequence for a new learning cycle.
  Future<void> resetCycle(
    List<Map<String, dynamic>> rawQuestions, {
    SharedPreferences? prefs,
  }) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    _sequence = buildBalancedSequence(rawQuestions, seed: DateTime.now().millisecondsSinceEpoch);
    _currentIndex = 0;
    _completedIds.clear();
    _skippedIds.clear();

    await sp.setStringList(_prefKeySequence, _sequence);
    await sp.setInt(_prefKeyIndex, 0);
    await sp.remove(_prefKeyCompletedIds);
    await sp.remove(_prefKeySkippedIds);
  }
}

