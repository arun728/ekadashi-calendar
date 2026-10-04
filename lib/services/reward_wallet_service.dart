import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'premium_service.dart';

/// Per-account durable outbox. Only UID/status leaves the device after consent.
/// A new device never interprets absent local history as cloud deletion.
class RewardWalletService extends ChangeNotifier {
  RewardWalletService(this.backend);
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  final PremiumBackend backend;
  int coins = 0;
  String? error;
  bool busy = false;
  Future<void> _tail = Future.value();
  String _key(String account) => 'rewards_v1_$account';
  Map<String, dynamic> _read(SharedPreferences p, String account) =>
      jsonDecode(
            p.getString(_key(account)) ??
                '{"consent":false,"owned":{},"queue":[]}',
          )
          as Map<String, dynamic>;
  Future<void> _write(
    SharedPreferences p,
    String account,
    Map<String, dynamic> value,
  ) async {
    if (!await p.setString(_key(account), jsonEncode(value))) {
      throw StateError('Reward storage failed');
    }
  }

  Future<void> activate(String account) async {
    final p = await SharedPreferences.getInstance();
    final value = _read(p, account);
    value['consent'] = true;
    await _write(p, account, value);
  }

  Future<bool> active(String account) async =>
      _read(await SharedPreferences.getInstance(), account)['consent'] == true;
  Future<void> forget(String account) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(account));
    coins = 0;
    _notify();
  }

  Future<void> refresh() async {
    try {
      coins = (await backend.wallet())['coins'] as int;
      error = null;
    } catch (_) {
      error = 'premium_unavailable';
    }
    _notify();
  }

  Future<void> sync(
    String account,
    Map<String, String> snapshot,
    String context,
  ) {
    final copy = Map<String, String>.of(snapshot);
    final next = _tail.then((_) => _sync(account, copy, context));
    _tail = next.catchError((_) {
      error = 'premium_reward_sync_failed';
      _notify();
    });
    return _tail;
  }

  Future<void> _sync(
    String account,
    Map<String, String> snapshot,
    String context,
  ) async {
    final p = await SharedPreferences.getInstance();
    var value = _read(p, account);
    if (value['consent'] != true) return;
    busy = true;
    _notify();
    try {
      // Drain exact persisted mutations first, including after an interrupted
      // successful server call. Do not replace mutation keys after a timeout.
      Future<void> drain() async {
        final queue = value['queue'] as List<dynamic>;
        final owned = value['owned'] as Map<String, dynamic>;
        while (queue.isNotEmpty) {
          final body = Map<String, dynamic>.from(queue.first as Map);
          final response = await backend.record(body);
          final info = (response['observances'] as Map)[body['uid']] as Map;
          owned[body['uid'] as String] = {
            'status': body['status'],
            'version': info['version'],
          };
          coins = response['coins'] as int;
          queue.removeAt(0);
          await _write(p, account, value);
        }
      }

      await drain();
      value = _read(p, account);
      final owned = value['owned'] as Map<String, dynamic>;
      final queue = value['queue'] as List<dynamic>;
      for (final uid in {...snapshot.keys, ...owned.keys}) {
        final prior = owned[uid] as Map?;
        final status = snapshot[uid] ?? 'unrecorded';
        if (prior == null && status != 'observed') continue;
        if (prior?['status'] == status) continue;
        queue.add({
          'uid': uid,
          'status': status,
          'context': context,
          'expectedVersion': prior?['version'] ?? 0,
          'mutationKey': const Uuid().v4(),
        });
      }
      await _write(p, account, value);
      await drain();
      error = null;
    } catch (_) {
      error = 'premium_reward_sync_failed';
    }
    busy = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
