import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vrat_tracker_models.dart';
import 'ekadashi_service.dart';
import 'vrat_statistics_service.dart';
import 'achievement_evaluator.dart';
import '../data/tracker_history_store.dart';

/// Central service for Vrat Tracking and Achievement management.
/// Integrates Vrat Tracker, Vrat Statistics, and Achievement System as a single module.
class VratTrackerService extends ChangeNotifier {
  VratTrackerService({bool Function()? premiumAchievements})
    : _premiumAchievements = premiumAchievements ?? (() => false);
  final bool Function() _premiumAchievements;
  static const freeAchievementLimit = 3;

  Future<List<Achievement>> refreshAchievements(
    List<EkadashiDate> occurrences,
  ) {
    return _mutate(() async {
      if (!_trackerEnabled) return const <Achievement>[];
      final unlocked = _evaluateAchievementsInternal(occurrences);
      await _persistAchievements();
      notifyListeners();
      return unlocked;
    });
  }

  static const String _prefEnabledAtKey = 'vrat_tracker_enabled_at';
  static const String _prefAchievementsKey = 'vrat_tracker_user_achievements';
  static const String _prefNotifiedAchievementsKey =
      'vrat_tracker_notified_achievements';

  bool _isInitialized = false;
  bool _trackerEnabled = false;
  DateTime? _trackingEnabledAt;

  // History indexed by occurrenceId for duplicate prevention and fast lookups
  final Map<String, VratHistory> _historyByUid = {};
  final TrackerHistoryStore _historyStore = TrackerHistoryStore();
  Map<int, VratHistory> get _historyByOccurrenceId => {
    for (final record in _historyByUid.values)
      record.ekadashiOccurrenceId: record,
  };
  String? storageError;
  Future<void> _pendingMutation = Future.value();
  Future<T> _mutate<T>(Future<T> Function() action) {
    final result = _pendingMutation.then((_) => action());
    _pendingMutation = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  // Achievements indexed by achievementId
  final Map<String, UserAchievement> _userAchievements = {};

  // Track which achievements have already triggered a notification
  final Set<String> _notifiedAchievements = {};

  bool get isInitialized => _isInitialized;
  bool get trackerEnabled => _trackerEnabled;
  DateTime? get trackingEnabledAt => _trackingEnabledAt;
  Map<int, VratHistory> get history => Map.unmodifiable(_historyByOccurrenceId);
  Map<String, UserAchievement> get userAchievements =>
      Map.unmodifiable(_userAchievements);

  /// Load persisted tracker settings, history, and achievements
  Future<void> init({List<EkadashiDate>? occurrences}) async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Availability is free, independent of the legacy opt-in preference.
      // Only a storage failure can block writes, to protect private history.
      final enabledAtStr = prefs.getString(_prefEnabledAtKey);
      if (enabledAtStr != null && enabledAtStr.isNotEmpty) {
        _trackingEnabledAt = DateTime.tryParse(enabledAtStr);
      }

      final records = await _historyStore.load(prefs, occurrences ?? const []);
      _historyByUid.addAll({for (final r in records) r.occurrenceUid!: r});

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

      _trackingEnabledAt ??= DateTime.now().toUtc();
      if (!prefs.containsKey(_prefEnabledAtKey)) {
        await prefs.setString(
          _prefEnabledAtKey,
          _trackingEnabledAt!.toIso8601String(),
        );
      }
      _trackerEnabled = true;
      storageError = null;

      // 5. Evaluate achievements if occurrences provided
      if (occurrences != null && occurrences.isNotEmpty) {
        _evaluateAchievementsInternal(occurrences);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing VratTrackerService: $e');
      storageError = e.toString();
      _trackerEnabled = false;
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// Record an Ekadashi observance.
  ///
  /// Protects against duplicate records:
  /// - If a record for [ekadashiOccurrenceId] exists, it updates it.
  /// - Protects against marking future occurrences as Observed.
  Future<List<Achievement>> recordVrat({
    required int ekadashiOccurrenceId,
    String? occurrenceUid,
    required String ekadashiDate,
    required String ekadashiName,
    required ObservanceStatus status,
    FastingMethod? fastingMethod,
    String? fastingMethodOther,
    String? note,
    String? tradition,
    String? timezone,
    List<EkadashiDate>? occurrences,
  }) {
    return _mutate(
      () => _recordVrat(
        ekadashiOccurrenceId: ekadashiOccurrenceId,
        occurrenceUid: occurrenceUid,
        ekadashiDate: ekadashiDate,
        ekadashiName: ekadashiName,
        status: status,
        fastingMethod: fastingMethod,
        fastingMethodOther: fastingMethodOther,
        note: note,
        tradition: tradition,
        timezone: timezone,
        occurrences: occurrences,
      ),
    );
  }

  Future<List<Achievement>> _recordVrat({
    required int ekadashiOccurrenceId,
    String? occurrenceUid,
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
    // Keep the service boundary authoritative: UI controls can be bypassed by
    // stale routes, accessibility actions, or future callers.
    if (!_trackerEnabled || _isFutureDate(ekadashiDate)) return const [];

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    occurrenceUid ??=
        occurrences
            ?.where((e) => e.id == ekadashiOccurrenceId)
            .firstOrNull
            ?.occurrenceUid ??
        'ekadashi:${DateTime.parse(ekadashiDate).year}:${ekadashiOccurrenceId.toString().padLeft(2, '0')}';
    final existing = _historyByUid[occurrenceUid];

    final updatedRecord = VratHistory(
      id:
          existing?.id ??
          'vrat_${ekadashiOccurrenceId}_${DateTime.now().millisecondsSinceEpoch}',
      localProfileId: existing?.localProfileId ?? 'default',
      ekadashiOccurrenceId: ekadashiOccurrenceId,
      occurrenceUid: occurrenceUid,
      locationContext: existing?.locationContext,
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

    final staged = {..._historyByUid, occurrenceUid: updatedRecord};
    final prefs = await SharedPreferences.getInstance();
    await _historyStore.save(prefs, staged.values.toList());
    _historyByUid[occurrenceUid] = updatedRecord;

    // Evaluate achievements
    List<Achievement> newlyUnlocked = [];
    if (occurrences != null && occurrences.isNotEmpty) {
      newlyUnlocked = _evaluateAchievementsInternal(occurrences);
    }

    // History is durable before achievements or UI are published.
    await _persistAchievements();

    notifyListeners();
    return newlyUnlocked;
  }

  /// Delete a Vrat record.
  /// Affects ONLY the vrat_history local store.
  Future<void> deleteVrat({
    required int ekadashiOccurrenceId,
    String? occurrenceUid,
    List<EkadashiDate>? occurrences,
  }) {
    return _mutate(
      () => _deleteVrat(
        ekadashiOccurrenceId: ekadashiOccurrenceId,
        occurrenceUid: occurrenceUid,
        occurrences: occurrences,
      ),
    );
  }

  Future<void> _deleteVrat({
    required int ekadashiOccurrenceId,
    String? occurrenceUid,
    List<EkadashiDate>? occurrences,
  }) async {
    if (!_trackerEnabled ||
        !_historyByOccurrenceId.containsKey(ekadashiOccurrenceId)) {
      return;
    }

    occurrenceUid ??=
        _historyByOccurrenceId[ekadashiOccurrenceId]?.occurrenceUid;
    final staged = {..._historyByUid}..remove(occurrenceUid);
    final prefs = await SharedPreferences.getInstance();
    await _historyStore.save(prefs, staged.values.toList());
    _historyByUid.remove(occurrenceUid);

    // Re-evaluate achievements after deletion
    if (occurrences != null && occurrences.isNotEmpty) {
      _evaluateAchievementsInternal(occurrences);
    }

    await _persistAchievements();

    notifyListeners();
  }

  /// Get record for an occurrence ID (O(1))
  VratHistory? getRecord(int occurrenceId) {
    return _historyByOccurrenceId[occurrenceId];
  }

  VratHistory? getRecordByUid(String uid) => _historyByUid[uid];

  /// Free users may record this many Ekadashis. Editing or deleting existing
  /// entries and viewing history, streaks and statistics always stay free.
  static const freeEntryLimit = 3;

  int get recordedEntryCount => _historyByUid.values
      .where((r) => r.status != ObservanceStatus.unrecorded)
      .length;

  /// Whether recording a new entry for [uid] needs premium.
  bool needsPremiumToRecord(String uid, {required bool premium}) =>
      !premium &&
      getRecordByUid(uid) == null &&
      recordedEntryCount >= freeEntryLimit;

  /// Get all history records sorted chronologically
  List<VratHistory> getAllRecords() {
    final list = _historyByUid.values.toList();
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
    List<EkadashiDate> occurrences,
  ) {
    final result = AchievementEvaluator.evaluate(
      history: getAllRecords(),
      occurrences: occurrences,
      currentAchievements: _userAchievements,
      newUnlockLimit: _premiumAchievements()
          ? null
          : (freeAchievementLimit -
                    _userAchievements.values.where((a) => a.isUnlocked).length)
                .clamp(0, freeAchievementLimit),
    );

    _userAchievements.clear();
    _userAchievements.addAll(result.updatedAchievements);

    // Filter to achievements that haven't been notified yet
    final unnotifiedUnlocks = <Achievement>[];
    for (final ach in result.newlyUnlocked) {
      if (!_notifiedAchievements.contains(ach.id)) {
        unnotifiedUnlocks.add(ach);
        _notifiedAchievements.add(ach.id);
      }
    }

    return unnotifiedUnlocks;
  }

  bool _isFutureDate(String date) {
    final parsed = DateTime.tryParse(date.trim());
    if (parsed == null) return true;
    final eventDay = DateTime(parsed.year, parsed.month, parsed.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return eventDay.isAfter(today);
  }

  /// Persist achievements to SharedPreferences
  Future<void> _persistAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _userAchievements.values.map((a) => a.toJson()).toList();
      await prefs.setString(_prefAchievementsKey, json.encode(list));
      await prefs.setStringList(
        _prefNotifiedAchievementsKey,
        _notifiedAchievements.toList(),
      );
    } catch (e) {
      debugPrint('⚠️ Error saving achievements: $e');
    }
  }
}
