import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vrat_tracker_models.dart';
import 'ekadashi_service.dart';
import 'vrat_statistics_service.dart';
import 'journey_rewards.dart';
import '../data/tracker_history_store.dart';

/// Central service for Vrat Tracking and Achievement management.
/// Integrates Vrat Tracker, Vrat Statistics, and Achievement System as a single module.
class VratTrackerService extends ChangeNotifier {
  VratTrackerService({
    bool Function()? premiumAchievements,
    DateTime Function()? now,
  }) : _premiumAchievements = premiumAchievements ?? (() => false),
       _now = now ?? DateTime.now;
  final DateTime Function() _now;
  String journeyTimezone = 'Asia/Kolkata';
  bool rewardsStorageError = false;
  bool _rewardsStoreCorrupt = false;
  bool badgeHaptics = true;
  final Set<String> _queuedAchievements = {};
  static const badgeEnvelopeKey = 'journey_badges_v1';

  JourneySummary journey(
    List<EkadashiDate> events, {
    Set<int>? completeYears,
    String? timezone,
  }) => JourneyRewards.calculate(
    occurrences: events,
    history: getAllRecords(),
    completeYears: completeYears ?? events.map((e) => e.date.year).toSet(),
    now: _now(),
    timezone: timezone ?? journeyTimezone,
  );

  Future<void> setBadgeHaptics(bool enabled) async {
    badgeHaptics = enabled;
    await (await SharedPreferences.getInstance()).setBool(
      'journey_badge_haptics',
      enabled,
    );
    notifyListeners();
  }

  Future<void> markAnnouncementsPresented(Iterable<String> ids) =>
      _mutate(() async {
        final old = {..._notifiedAchievements};
        _notifiedAchievements.addAll(ids);
        if (!await _persistAchievements()) {
          _notifiedAchievements
            ..clear()
            ..addAll(old);
        }
        notifyListeners();
      });
  final bool Function() _premiumAchievements;
  static const freeAchievementLimit = 3;

  Future<List<Achievement>> refreshAchievements(
    List<EkadashiDate> occurrences,
  ) {
    return _mutate(() async {
      if (!_trackerEnabled) return const <Achievement>[];
      final unlocked = _evaluateAchievementsInternal(occurrences);
      final saved = await _persistAchievements();
      if (!saved) _queuedAchievements.removeAll(unlocked.map((a) => a.id));
      notifyListeners();
      return saved ? unlocked : <Achievement>[];
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

      _userAchievements.clear();
      _notifiedAchievements
        ..clear()
        ..addAll(prefs.getStringList(_prefNotifiedAchievementsKey) ?? []);
      _queuedAchievements.clear();
      rewardsStorageError = false;
      _rewardsStoreCorrupt = false;
      badgeHaptics = prefs.getBool('journey_badge_haptics') ?? true;
      final envelope = prefs.getString(badgeEnvelopeKey);
      final legacy = prefs.getString(_prefAchievementsKey);
      try {
        if (envelope != null) {
          final data = jsonDecode(envelope) as Map<String, dynamic>;
          final rows = data['achievements'] as List;
          for (final row in rows) {
            final a = UserAchievement.fromJson(
              Map<String, dynamic>.from(row as Map),
            );
            _userAchievements[a.achievementId] = a;
          }
          _notifiedAchievements.addAll(
            (data['presented'] as List).cast<String>(),
          );
        } else if (legacy != null) {
          for (final row in jsonDecode(legacy) as List) {
            final a = UserAchievement.fromJson(
              Map<String, dynamic>.from(row as Map),
            );
            _userAchievements[a.achievementId] = a;
          }
        }
      } catch (_) {
        _userAchievements.clear();
        _rewardsStoreCorrupt = true;
        rewardsStorageError = true;
      }

      _trackingEnabledAt ??= _now().toUtc();
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
        _queuedAchievements.clear();
        await _persistAchievements();
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

    final nowUtc = _now().toUtc().toIso8601String();
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
          'vrat_${ekadashiOccurrenceId}_${_now().millisecondsSinceEpoch}',
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
    final saved = await _persistAchievements();
    if (!saved) _queuedAchievements.removeAll(newlyUnlocked.map((a) => a.id));
    notifyListeners();
    return saved ? newlyUnlocked : <Achievement>[];
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
    if (_rewardsStoreCorrupt) return [];
    final result = JourneyBadgeEvaluator.evaluate(
      summary: journey(occurrences),
      current: _userAchievements,
      now: _now(),
      newUnlockLimit: _premiumAchievements()
          ? null
          : (freeAchievementLimit -
                    _userAchievements.values.where((a) => a.isUnlocked).length)
                .clamp(0, freeAchievementLimit),
    );
    _userAchievements
      ..clear()
      ..addAll(result.updated);
    final pending =
        JourneyBadgeCatalog.all(occurrences.map((e) => e.date.year).toList())
            .where(
              (b) =>
                  _userAchievements[b.id]?.isUnlocked == true &&
                  !_notifiedAchievements.contains(b.id) &&
                  !_queuedAchievements.contains(b.id),
            )
            .map((b) => b.achievement)
            .toList();
    _queuedAchievements.addAll(pending.map((a) => a.id));
    return pending;
  }

  bool _isFutureDate(String date) {
    final parsed = DateTime.tryParse(date.trim());
    if (parsed == null) return true;
    final eventDay = DateTime(parsed.year, parsed.month, parsed.day);
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    return eventDay.isAfter(today);
  }

  /// One local envelope commits badges and presentation markers together.
  /// Secondary failures never block or overwrite the observance journal.
  Future<bool> _persistAchievements() async {
    if (_rewardsStoreCorrupt) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = _userAchievements.values.toList()
        ..sort((a, b) => a.achievementId.compareTo(b.achievementId));
      final presented = _notifiedAchievements.toList()..sort();
      final raw = jsonEncode({
        'achievements': rows.map((a) => a.toJson()).toList(),
        'presented': presented,
      });
      final saved =
          await prefs.setString(badgeEnvelopeKey, raw) &&
          prefs.getString(badgeEnvelopeKey) == raw;
      rewardsStorageError = !saved;
      return saved;
    } catch (_) {
      rewardsStorageError = true;
      return false;
    }
  }
}
