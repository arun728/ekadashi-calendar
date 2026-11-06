library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wisdom_question.dart';
import 'wisdom_eligibility_service.dart';
import 'wisdom_question_service.dart';

/// Persists question attempts, independent wisdom points, daily question
/// assignments, reminder preferences, and review history using SharedPreferences.
///
/// Keeps Wisdom points completely separate from Vrat fasting achievements.
class WisdomProgressStore extends ChangeNotifier {
  static final instance = WisdomProgressStore();

  static const _attemptsKey = 'wisdom_question_attempts';
  static const _dailyQuestionKey = 'wisdom_daily_question';
  static const _reminderEnabledKey = 'wisdom_reminder_enabled';
  static const _reminderHourKey = 'wisdom_reminder_hour';
  static const _reminderMinuteKey = 'wisdom_reminder_minute';
  static const _previewModeKey = 'wisdom_preview_mode';

  final Map<String, QuestionAttempt> _attempts = {};

  String? _dailyQuestionId;
  String? _dailyQuestionDate; // 'YYYY-MM-DD'
  bool _dailyFinished = false;

  bool _reminderEnabled = false;
  int _reminderHour = 8;
  int _reminderMinute = 0;
  bool _previewMode = false;
  bool _loaded = false;

  /// All recorded attempts, keyed by question ID.
  Map<String, QuestionAttempt> get attempts => Map.unmodifiable(_attempts);

  /// Whether the daily question reminder is enabled.
  bool get reminderEnabled => _reminderEnabled;

  /// Configured reminder hour (0-23).
  int get reminderHour => _reminderHour;

  /// Configured reminder minute (0-59).
  int get reminderMinute => _reminderMinute;

  /// Whether development/admin preview mode is active.
  bool get previewMode => _previewMode;

  /// Whether today's daily question has been completed or marked finished.
  bool get isDailyFinished => _dailyFinished;

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

    // Load attempts with safe migration for legacy v1 records
    final attemptsJson = prefs.getString(_attemptsKey);
    if (attemptsJson != null && attemptsJson.isNotEmpty) {
      final decoded = jsonDecode(attemptsJson) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          _attempts[entry.key] = QuestionAttempt.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    // Load daily question
    final dailyJson = prefs.getString(_dailyQuestionKey);
    if (dailyJson != null && dailyJson.isNotEmpty) {
      final decoded = jsonDecode(dailyJson) as Map<String, dynamic>;
      _dailyQuestionId = decoded['questionId'] as String?;
      _dailyQuestionDate = decoded['date'] as String?;
      _dailyFinished = decoded['finished'] as bool? ?? false;
    }

    // Load reminder preferences
    _reminderEnabled = prefs.getBool(_reminderEnabledKey) ?? false;
    _reminderHour = prefs.getInt(_reminderHourKey) ?? 8;
    _reminderMinute = prefs.getInt(_reminderMinuteKey) ?? 0;
    _previewMode = prefs.getBool(_previewModeKey) ?? false;

    // Sync answered IDs to question selection service
    WisdomQuestionService.instance.selectionService.markCompleted(
      _attempts.keys.toSet(),
    );

    _loaded = true;
    notifyListeners();
  }

  /// Record a question attempt.
  ///
  /// Prevents duplicate rewards: if question was already answered,
  /// returns 0 points. Respects preview mode, skip, and review modes.
  Future<int> recordAttempt({
    required String questionId,
    required String selectedOption,
    required bool isCorrect,
    bool isSkipped = false,
    bool isReview = false,
    bool isProductionEligible = true,
  }) async {
    // If already recorded and this is not review, prevent duplicate points
    if (_attempts.containsKey(questionId) && !isReview) {
      return 0;
    }

    final points = WisdomEligibilityService.instance.calculateAwardedPoints(
      isCorrect: isCorrect,
      isProductionEligible: isProductionEligible && !_previewMode,
      isSkipped: isSkipped,
      isReview: isReview,
    );

    final attempt = QuestionAttempt(
      questionId: questionId,
      selectedOption: selectedOption,
      isCorrect: isCorrect,
      pointsAwarded: points,
      answeredAtUTC: DateTime.now().toUtc().toIso8601String(),
      isSkipped: isSkipped,
      isReview: isReview,
    );

    _attempts[questionId] = attempt;
    WisdomQuestionService.instance.selectionService.markCompleted({questionId});

    await _persistAttempts();
    notifyListeners();
    return points;
  }

  /// Persist the daily question ID for a specific date.
  Future<void> setDailyQuestion(
    String questionId,
    DateTime localDate, {
    bool finished = false,
  }) async {
    _dailyQuestionId = questionId;
    _dailyQuestionDate = _dateKey(localDate);
    _dailyFinished = finished;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dailyQuestionKey,
      jsonEncode({
        'questionId': questionId,
        'date': _dailyQuestionDate,
        'finished': _dailyFinished,
      }),
    );
    notifyListeners();
  }

  /// Mark the daily question as finished for today.
  Future<void> finishForToday(DateTime localDate) async {
    _dailyFinished = true;
    if (_dailyQuestionId != null) {
      await setDailyQuestion(_dailyQuestionId!, localDate, finished: true);
    }
  }

  /// Toggle preview mode.
  Future<void> setPreviewMode(bool enabled) async {
    _previewMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_previewModeKey, enabled);
    notifyListeners();
  }

  /// Set reminder time.
  Future<void> setReminderTime(int hour, int minute) async {
    _reminderHour = hour;
    _reminderMinute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);
    notifyListeners();
  }

  /// Toggle the daily question reminder on/off.
  Future<void> setReminderEnabled(bool enabled) async {
    _reminderEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, enabled);
    notifyListeners();
  }

  /// Whether [questionId] has already been answered.
  bool isAnswered(String questionId) => _attempts.containsKey(questionId);

  /// The attempt for [questionId], or null if unanswered.
  QuestionAttempt? getAttempt(String questionId) => _attempts[questionId];

  /// Set of all answered question IDs.
  Set<String> get answeredIds => _attempts.keys.toSet();

  /// Incorrectly answered question IDs for review mode.
  List<String> get incorrectQuestionIds => _attempts.entries
      .where((e) => !e.value.isCorrect && !e.value.isSkipped)
      .map((e) => e.key)
      .toList();

  /// Skipped question IDs for review mode.
  List<String> get skippedQuestionIds => _attempts.entries
      .where((e) => e.value.isSkipped)
      .map((e) => e.key)
      .toList();

  /// Compute aggregate statistics.
  WisdomStats get stats {
    final categoryAnswered = <String, int>{};
    final categoryCorrect = <String, int>{};
    int totalCorrect = 0;
    int totalPoints = 0;
    int totalSkipped = 0;

    for (final attempt in _attempts.values) {
      if (attempt.isSkipped) {
        totalSkipped++;
      } else if (attempt.isCorrect) {
        totalCorrect++;
        totalPoints += attempt.pointsAwarded;
      }
    }

    return WisdomStats(
      totalAnswered: _attempts.length,
      totalCorrect: totalCorrect,
      totalPoints: totalPoints,
      totalSkipped: totalSkipped,
      categoryAnswered: categoryAnswered,
      categoryCorrect: categoryCorrect,
    );
  }

  /// Reset in-memory state for testing.
  Future<void> resetForTesting() async {
    _attempts.clear();
    _dailyQuestionId = null;
    _dailyQuestionDate = null;
    _dailyFinished = false;
    _reminderEnabled = false;
    _reminderHour = 8;
    _reminderMinute = 0;
    _previewMode = false;
    _loaded = false;
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
