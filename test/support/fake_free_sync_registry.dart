import 'package:ekadashi_calendar/services/free_sync_registry.dart';

/// Test stand-in for the free per-Google-account record of the one free sync.
class FakeFreeSyncRegistry implements FreeSyncRegistry {
  /// Month already recorded for this account (e.g. before a reinstall).
  DateTime? recorded;
  bool fail = false;
  final tokens = <String>[];
  @override
  Future<bool> isUsed(String googleIdToken) async {
    tokens.add(googleIdToken);
    if (fail) throw StateError('Free sync registry unreachable');
    return recorded != null;
  }

  @override
  Future<void> record(String googleIdToken, DateTime month) async {
    tokens.add(googleIdToken);
    if (fail) throw StateError('Free sync registry unreachable');
    recorded ??= month;
  }
}
