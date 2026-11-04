import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wisdom_question.dart';

/// Persists question attempts, points, and daily question assignment using
/// SharedPreferences. Integrates with the existing Achievement Module's
/// storage pattern (same as VratTrackerService / TrackerHistoryStore).
class WisdomProgressStore extends ChangeNotifier {
  static final instance = WisdomProgressStore();

  static const _attemptsKey = 'wisdom_question_attempts';
  static const _dailyQuestionKey = 'wisdom_daily_question';
  static const _reminderEnabledKey = 'wisdom_reminder_enabled';

  final Map<String, QuestionAttempt> _attempts = {};

  /// The question ID assigned for today's date (persisted so refreshes
  /// don't change it).
  String? _dailyQuestionId;
  String? _dailyQuestionDate; // 'YYYY-MM-DD'

  bool _reminderEnabled = false;
  bool _loaded = false;

  /// All recorded attempts, keyed by question ID.
  Map<String, QuestionAttempt> get attempts => Map.unmodifiable(_attempts);

  /// Whether the daily question reminder is enabled.
  bool get reminderEnabled => _reminderEnabled;

  /// The persisted daily question ID for [localDate], or null if none yet.
  String? dailyQuestionIdFor(DateTime localDate) {
    final dateStr = _dateKey(localDate);
    if (_dailyQuestionDate == dateStr) return _dailyQuestionId;
    return null;
  }

  /// Load persisted data from SharedPreferences.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    // Load attempts.
    final attemptsJson = prefs.getString(_attemptsKey);
    if (attemptsJson != null && attemptsJson.isNotEmpty) {
      final decoded = jsonDecode(attemptsJson) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        _attempts[entry.key] = QuestionAttempt.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    // Load daily question.
    final dailyJson = prefs.getString(_dailyQuestionKey);
    if (dailyJson != null && dailyJson.isNotEmpty) {
      final decoded = jsonDecode(dailyJson) as Map<String, dynamic>;
      _dailyQuestionId = decoded['questionId'] as String?;
      _dailyQuestionDate = decoded['date'] as String?;
    }

    // Load reminder preference.
    _reminderEnabled = prefs.getBool(_reminderEnabledKey) ?? false;

    _loaded = true;
    notifyListeners();
  }

  /// Record a question attempt. Returns the points awarded (0 if already
  /// answered or incorrect). Prevents duplicate points.
  Future<int> recordAttempt({
    required String questionId,
    required String selectedOption,
    required bool isCorrect,
  }) async {
    // Duplicate prevention: already answered this question.
    if (_attempts.containsKey(questionId)) return 0;

    final points = isCorrect ? 1 : 0;
    final attempt = QuestionAttempt(
      questionId: questionId,
      selectedOption: selectedOption,
      isCorrect: isCorrect,
      pointsAwarded: points,
      answeredAtUTC: DateTime.now().toUtc().toIso8601String(),
    );
    _attempts[questionId] = attempt;
    await _persistAttempts();
    notifyListeners();
    return points;
  }

  /// Persist the daily question ID for a specific date.
  Future<void> setDailyQuestion(String questionId, DateTime localDate) async {
    _dailyQuestionId = questionId;
    _dailyQuestionDate = _dateKey(localDate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyQuestionKey, jsonEncode({
      'questionId': questionId,
      'date': _dailyQuestionDate,
    }));
    notifyListeners();
  }

  /// Whether [questionId] has already been answered.
  bool isAnswered(String questionId) => _attempts.containsKey(questionId);

  /// The attempt for [questionId], or null if unanswered.
  QuestionAttempt? getAttempt(String questionId) => _attempts[questionId];

  /// Set of all answered question IDs.
  Set<String> get answeredIds => _attempts.keys.toSet();

  /// Compute aggregate statistics.
  WisdomStats get stats {
    final categoryAnswered = <String, int>{};
    final categoryCorrect = <String, int>{};
    int totalCorrect = 0;
    int totalPoints = 0;

    for (final attempt in _attempts.values) {
      if (attempt.isCorrect) {
        totalCorrect++;
        totalPoints += attempt.pointsAwarded;
      }
      // Category tracking requires the question data; tracked separately
      // if needed. For now, basic stats.
    }

    return WisdomStats(
      totalAnswered: _attempts.length,
      totalCorrect: totalCorrect,
      totalPoints: totalPoints,
      categoryAnswered: categoryAnswered,
      categoryCorrect: categoryCorrect,
    );
  }

  /// Clear in-memory state for testing.
  Future<void> resetForTesting() async {
    _attempts.clear();
    _dailyQuestionId = null;
    _dailyQuestionDate = null;
    _reminderEnabled = false;
    _loaded = false;
    notifyListeners();
  }

  /// Toggle the daily question reminder on/off.
  Future<void> setReminderEnabled(bool enabled) async {
    _reminderEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> _persistAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _attempts.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_attemptsKey, encoded);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

