import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vrat_tracker_models.dart';
import '../services/ekadashi_service.dart';

/// One versioned value is the commit boundary. Legacy data and a snapshot of all
/// tracking preferences remain available for recovery; no record is discarded.
class TrackerHistoryStore {
  static const key = 'vrat_tracker_history_v2';
  static const legacyKey = 'vrat_tracker_history';
  static const backupKey = 'vrat_tracker_migration_backup_v1';
  List<dynamic> _unresolved = [];

  Future<List<VratHistory>> load(
    SharedPreferences prefs,
    List<EkadashiDate> occurrences,
  ) async {
    final current = prefs.getString(key);
    if (current != null) {
      final envelope = jsonDecode(current) as Map<String, dynamic>;
      if (envelope['schemaVersion'] != 2) {
        throw const FormatException('Unsupported tracker storage version');
      }
      _unresolved = List<dynamic>.from(envelope['unresolved'] as List);
      final seen = <String>{};
      return (envelope['records'] as List).map((row) {
        final record = VratHistory.fromJson(
          Map<String, dynamic>.from(row as Map),
        );
        if (record.occurrenceUid == null || !seen.add(record.occurrenceUid!)) {
          throw const FormatException('Invalid or duplicate tracker identity');
        }
        return record;
      }).toList();
    }
    _unresolved = [];
    final legacy = prefs.getString(legacyKey);
    final rows = legacy == null ? <dynamic>[] : jsonDecode(legacy) as List;
    final records = <VratHistory>[];
    final seen = <String>{};
    final nativeIds = <int>{};
    for (final row in rows) {
      try {
        final old = VratHistory.fromJson(Map<String, dynamic>.from(row as Map));
        final date = DateTime.tryParse(old.ekadashiDate);
        if (date == null || old.ekadashiOccurrenceId <= 0) {
          throw const FormatException('Unresolvable legacy record');
        }
        final matches = occurrences.where(
          (e) =>
              e.date.year == date.year &&
              (e.legacyId == old.ekadashiOccurrenceId ||
                  e.id == old.ekadashiOccurrenceId),
        );
        // Original v1 records are unambiguously year 2026. Other years require
        // an explicit source occurrence; unknown records remain in quarantine.
        final e = matches.firstOrNull;
        if (e == null && date.year != 2026) {
          throw const FormatException('Unknown legacy year');
        }
        final uid =
            old.occurrenceUid ??
            e?.occurrenceUid ??
            'ekadashi:2026:${old.ekadashiOccurrenceId.toString().padLeft(2, '0')}';
        final nativeId = e?.id ?? old.ekadashiOccurrenceId;
        if (!seen.add(uid) || !nativeIds.add(nativeId)) {
          throw const FormatException('Duplicate legacy record');
        }
        records.add(
          old.copyWith(occurrenceUid: uid, ekadashiOccurrenceId: nativeId),
        );
      } catch (_) {
        _unresolved.add(row);
      }
    }
    if (!prefs.containsKey(backupKey)) {
      final snapshot = {
        for (final k in prefs.getKeys())
          if (k.startsWith('vrat_tracker_')) k: prefs.get(k),
      };
      if (!await prefs.setString(backupKey, jsonEncode(snapshot))) {
        throw StateError('Cannot back up tracker history');
      }
    }
    await save(prefs, records);
    return records;
  }

  Future<void> save(SharedPreferences prefs, List<VratHistory> records) async {
    final encoded = jsonEncode({
      'schemaVersion': 2,
      'records': records.map((r) => r.toJson()).toList(),
      'unresolved': _unresolved,
    });
    try {
      if (!await prefs.setString(key, encoded) ||
          prefs.getString(key) != encoded) {
        throw StateError('Tracker history could not be saved');
      }
    } catch (_) {
      // SharedPreferences updates its cache before awaiting native storage.
      // Refresh it after a failed write so another service cannot read a false
      // success from the same in-process cache.
      try {
        await prefs.reload();
      } catch (_) {}
      rethrow;
    }
  }
}
