import 'dart:async';
import 'package:flutter/foundation.dart';

abstract interface class PremiumBackend {
  Future<Map<String, dynamic>> session({bool interactive = true});
  Future<Map<String, dynamic>> verify(String token, String product);
  Future<Map<String, dynamic>> wallet();
  Future<Map<String, dynamic>> record(Map<String, dynamic> body);
  Future<Map<String, dynamic>> redeem(String key);
  Future<void> deleteAccount();
}

/// Paid access is a short verified server lease, never a persisted local flag.
class PremiumService extends ChangeNotifier {
  PremiumService({
    required this.backend,
    int Function()? elapsedMillis,
    this.startLeaseTimer = true,
  }) {
    _watch.start();
    _elapsed = elapsedMillis ?? (() => _watch.elapsedMilliseconds);
  }
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  final PremiumBackend backend;
  final bool startLeaseTimer;
  final Stopwatch _watch = Stopwatch();
  late final int Function() _elapsed;
  Timer? _expiryTimer;
  int _expires = 0;
  String? accountId;
  String? error;
  bool busy = false;
  bool autoRenew = false;
  bool lifetime = false;
  String? redemptionState;
  bool get isPremium => _elapsed() < _expires;
  bool get connected => accountId != null;
  void _accept(Map<String, dynamic> response) {
    _expires = 0;
    _expiryTimer?.cancel();
    autoRenew = response['autoRenew'] == true;
    lifetime = response['lifetime'] == true;
    final now = DateTime.parse(response['serverTime'] as String).toUtc();
    if (response['premium'] == true) {
      final remaining = lifetime
          ? const Duration(minutes: 5)
          : DateTime.parse(
              response['validUntil'] as String,
            ).toUtc().difference(now);
      final duration = remaining.inMilliseconds.clamp(0, 300000);
      _expires = _elapsed() + duration;
      if (duration > 0 && startLeaseTimer) {
        _expiryTimer = Timer(Duration(milliseconds: duration), () {
          _notify();
          if (connected) connect(interactive: false);
        });
      }
    }
  }

  Future<void> connect({bool interactive = true}) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      final value = await backend.session(interactive: interactive);
      if (_disposed) return;
      accountId = value['accountId'] as String;
      _accept(value);
    } catch (_) {
      _expires = 0;
      error = 'premium_unavailable';
    }
    busy = false;
    _notify();
  }

  Future<bool> verify(String token, String product) async {
    try {
      final value = await backend.verify(token, product);
      if (_disposed) return value['acknowledged'] == true;
      _accept(value);
      error = null;
      _notify();
      return value['acknowledged'] == true;
    } catch (_) {
      _expires = 0;
      error = 'premium_verification_failed';
      _notify();
      return false;
    }
  }

  Future<void> redeem(String key) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      final response = await backend.redeem(key);
      if (_disposed) return;
      redemptionState = response['state'] as String?;
      _accept(response);
    } catch (_) {
      error = 'premium_redemption_failed';
    }
    busy = false;
    _notify();
  }

  Future<void> deleteAccount() async {
    await backend.deleteAccount();
    reset();
  }

  void reset() {
    accountId = null;
    _expires = 0;
    autoRenew = false;
    lifetime = false;
    _expiryTimer?.cancel();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _expires = 0;
    _expiryTimer?.cancel();
    _watch.stop();
    super.dispose();
  }
}
