import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vrat_tracker_models.dart';
import 'ekadashi_service.dart';
import 'vrat_statistics_service.dart';
import 'achievement_evaluator.dart';

/// Callback signature when an achievement is unlocked
typedef AchievementUnlockCallback = void Function(Achievement achievement);

/// Central service for Vrat Tracking and Achievement management.
/// Integrates Vrat Tracker, Vrat Statistics, and Achievement System as a single module.
class VratTrackerService extends ChangeNotifier {
  static const String _prefEnabledKey = 'vrat_tracker_enabled';
  static const String _prefEnabledAtKey = 'vrat_tracker_enabled_at';
  static const String _prefHistoryKey = 'vrat_tracker_history';
  static const String _prefAchievementsKey = 'vrat_tracker_user_achievements';
  static const String _prefNotifiedAchievementsKey = 'vrat_tracker_notified_achievements';

  bool _isInitialized = false;
  bool _trackerEnabled = false;
  DateTime? _trackingEnabledAt;

  // History indexed by occurrenceId for duplicate prevention and fast lookups
  final Map<int, VratHistory> _historyByOccurrenceId = {};

  // Achievements indexed by achievementId
  final Map<String, UserAchievement> _userAchievements = {};

  // Track which achievements have already triggered a notification
  final Set<String> _notifiedAchievements = {};

  // Optional unlock callback for UI notification banners
  AchievementUnlockCallback? onAchievementUnlocked;

  bool get isInitialized => _isInitialized;
  bool get trackerEnabled => _trackerEnabled;
  DateTime? get trackingEnabledAt => _trackingEnabledAt;
  Map<int, VratHistory> get history => Map.unmodifiable(_historyByOccurrenceId);
  Map<String, UserAchievement> get userAchievements => Map.unmodifiable(_userAchievements);

  /// Load persisted tracker settings, history, and achievements
  Future<void> init({List<EkadashiDate>? occurrences}) async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Tracker is disabled by default (Opt-in requirement)
      _trackerEnabled = prefs.getBool(_prefEnabledKey) ?? false;

      final enabledAtStr = prefs.getString(_prefEnabledAtKey);
      if (enabledAtStr != null && enabledAtStr.isNotEmpty) {
        _trackingEnabledAt = DateTime.tryParse(enabledAtStr);
      }

      // 2. Load Vrat History
      final historyJsonStr = prefs.getString(_prefHistoryKey);
      if (historyJsonStr != null && historyJsonStr.isNotEmpty) {
        final List<dynamic> decodedList = json.decode(historyJsonStr);
        for (final item in decodedList) {
          if (item is Map<String, dynamic>) {
            final record = VratHistory.fromJson(item);
            _historyByOccurrenceId[record.ekadashiOccurrenceId] = record;
          }
        }
      }

      // 3. Load User Achievements
      final achievementsJsonStr = prefs.getString(_prefAchievementsKey);
      if (achievementsJsonStr != null && achievementsJsonStr.isNotEmpty) {
        final List<dynamic> decodedList = json.decode(achievementsJsonStr);
        for (final item in decodedList) {
          if (item is Map<String, dynamic>) {
            final ua = UserAchievement.fromJson(item);
            _userAchievements[ua.achievementId] = ua;
          }
        }
      }

      // 4. Load notified achievement IDs
      final notifiedList = prefs.getStringList(_prefNotifiedAchievementsKey);
      if (notifiedList != null) {
        _notifiedAchievements.addAll(notifiedList);
      }

      // 5. Evaluate achievements if occurrences provided
      if (occurrences != null && occurrences.isNotEmpty) {
        _evaluateAchievementsInternal(occurrences, triggerNotifications: false);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error initializing VratTrackerService: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Enable Vrat Tracker (explicit opt-in)
  Future<void> enableTracker({List<EkadashiDate>? occurrences}) async {
    _trackerEnabled = true;
    _trackingEnabledAt = DateTime.now().toUtc();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, true);
    await prefs.setString(_prefEnabledAtKey, _trackingEnabledAt!.toIso8601String());

    if (occurrences != null && occurrences.isNotEmpty) {
      _evaluateAchievementsInternal(occurrences, triggerNotifications: false);
    }

    notifyListeners();
  }

  /// Disable Vrat Tracker.
  /// Does NOT delete existing Vrat history or earned achievements.
  Future<void> disableTracker() async {
    _trackerEnabled = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, false);

    notifyListeners();
  }

  /// Record an Ekadashi observance.
  ///
  /// Protects against duplicate records:
  /// - If a record for [ekadashiOccurrenceId] exists, it updates it.
  /// - Protects against marking future occurrences as Observed.
  Future<List<Achievement>> recordVrat({
    required int ekadashiOccurrenceId,
    required String ekadashiDate,
    required String ekadashiName,
    required ObservanceStatus status,
    FastingMethod? fastingMethod,
    String? fastingMethodOther,
    String? note,
    String? tradition,
    String? timezone,
    List<EkadashiDate>? occurrences,
  }) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final existing = _historyByOccurrenceId[ekadashiOccurrenceId];

    final updatedRecord = VratHistory(
      id: existing?.id ?? 'vrat_${ekadashiOccurrenceId}_${DateTime.now().millisecondsSinceEpoch}',
      localProfileId: existing?.localProfileId ?? 'default',
      ekadashiOccurrenceId: ekadashiOccurrenceId,
      ekadashiDate: ekadashiDate,
      ekadashiName: ekadashiName,
      status: status,
      fastingMethod: fastingMethod,
      fastingMethodOther: fastingMethodOther,
      note: note,
      recordedAtUTC: existing?.recordedAtUTC ?? nowUtc,
      updatedAtUTC: nowUtc,
      tradition: tradition ?? existing?.tradition,
      timezone: timezone ?? existing?.timezone,
    );

    _historyByOccurrenceId[ekadashiOccurrenceId] = updatedRecord;

    // Evaluate achievements
    List<Achievement> newlyUnlocked = [];
    if (occurrences != null && occurrences.isNotEmpty) {
      newlyUnlocked = _evaluateAchievementsInternal(occurrences, triggerNotifications: true);
    }

    // Persist changes
    await _persistHistory();
    await _persistAchievements();

    notifyListeners();
    return newlyUnlocked;
  }

  /// Delete a Vrat record.
  /// Affects ONLY the vrat_history local store.
  Future<void> deleteVrat({
    required int ekadashiOccurrenceId,
    List<EkadashiDate>? occurrences,
  }) async {
    if (!_historyByOccurrenceId.containsKey(ekadashiOccurrenceId)) return;

    _historyByOccurrenceId.remove(ekadashiOccurrenceId);

    // Re-evaluate achievements after deletion
    if (occurrences != null && occurrences.isNotEmpty) {
      _evaluateAchievementsInternal(occurrences, triggerNotifications: false);
    }

    await _persistHistory();
    await _persistAchievements();

    notifyListeners();
  }

  /// Get record for an occurrence ID (O(1))
  VratHistory? getRecord(int occurrenceId) {
    return _historyByOccurrenceId[occurrenceId];
  }

  /// Get all history records sorted chronologically
  List<VratHistory> getAllRecords() {
    final list = _historyByOccurrenceId.values.toList();
    list.sort((a, b) => a.ekadashiDate.compareTo(b.ekadashiDate));
    return list;
  }

  /// Calculate current streak for provided occurrences
  int getCurrentStreak(List<EkadashiDate> occurrences) {
    return VratStatisticsService.calculateCurrentStreak(
      occurrences: occurrences,
      historyByOccurrenceId: _historyByOccurrenceId,
      trackingEnabledAt: _trackingEnabledAt,
    );
  }

  /// Calculate longest streak for provided occurrences
  int getLongestStreak(List<EkadashiDate> occurrences) {
    return VratStatisticsService.calculateLongestStreak(
      occurrences: occurrences,
      historyByOccurrenceId: _historyByOccurrenceId,
    );
  }

  /// Calculate annual stats for provided occurrences and year
  VratYearStats getAnnualStats({
    required int year,
    required List<EkadashiDate> occurrences,
  }) {
    return VratStatisticsService.calculateAnnualStats(
      year: year,
      occurrences: occurrences,
      historyByOccurrenceId: _historyByOccurrenceId,
    );
  }

  /// Helper to evaluate achievements internally and manage one-time notifications
  List<Achievement> _evaluateAchievementsInternal(
    List<EkadashiDate> occurrences, {
    required bool triggerNotifications,
  }) {
    final result = AchievementEvaluator.evaluate(
      history: getAllRecords(),
      occurrences: occurrences,
      currentAchievements: _userAchievements,
    );

    _userAchievements.clear();
    _userAchievements.addAll(result.updatedAchievements);

    // Filter to achievements that haven't been notified yet
    final unnotifiedUnlocks = <Achievement>[];
    for (final ach in result.newlyUnlocked) {
      if (!_notifiedAchievements.contains(ach.id)) {
        unnotifiedUnlocks.add(ach);
        _notifiedAchievements.add(ach.id);
        if (triggerNotifications && onAchievementUnlocked != null) {
          onAchievementUnlocked!(ach);
        }
      }
    }

    return unnotifiedUnlocks;
  }

  /// Persist history to SharedPreferences
  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _historyByOccurrenceId.values.map((v) => v.toJson()).toList();
      await prefs.setString(_prefHistoryKey, json.encode(list));
    } catch (e) {
      debugPrint('⚠️ Error saving vrat history: $e');
    }
  }

  /// Persist achievements to SharedPreferences
  Future<void> _persistAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _userAchievements.values.map((a) => a.toJson()).toList();
      await prefs.setString(_prefAchievementsKey, json.encode(list));
      await prefs.setStringList(_prefNotifiedAchievementsKey, _notifiedAchievements.toList());
    } catch (e) {
      debugPrint('⚠️ Error saving achievements: $e');
    }
  }
}
