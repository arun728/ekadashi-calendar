import 'package:flutter/foundation.dart';

/// What Google Play Billing reports as currently owned on this device.
abstract interface class PlayEntitlementSource {
  /// Product IDs in the PURCHASED state: an active (or grace-period)
  /// subscription or the lifetime product. Throws when Play is unavailable.
  Future<Set<String>> ownedProducts();
}

/// Premium access comes only from Google Play's purchase record. It is never
/// persisted locally and is not tied to a Google (Calendar) sign-in.
class PremiumService extends ChangeNotifier {
  PremiumService({required this.entitlements});

  static const subscriptionId = 'ekadashi_premium';
  static const lifetimeId = 'ekadashi_premium_lifetime';

  final PlayEntitlementSource entitlements;
  bool _disposed = false;
  bool subscribed = false;
  bool lifetime = false;
  bool busy = false;
  String? error;

  bool get isPremium => subscribed || lifetime;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Applies Play's complete owned-product list, revoking anything missing.
  void applyOwned(Set<String> owned) {
    if (_disposed) return;
    subscribed = owned.contains(subscriptionId);
    lifetime = owned.contains(lifetimeId);
    error = null;
    _notify();
  }

  /// Adds one completed purchase reported by the Play purchase stream.
  void grant(String productId) {
    if (_disposed) return;
    if (productId == subscriptionId) subscribed = true;
    if (productId == lifetimeId) lifetime = true;
    error = null;
    _notify();
  }

  /// Re-reads owned purchases from Google Play (startup, resume, restore).
  Future<void> refresh() async {
    if (busy || _disposed) return;
    busy = true;
    _notify();
    try {
      final owned = await entitlements.ownedProducts();
      if (_disposed) return;
      busy = false;
      applyOwned(owned);
    } catch (_) {
      if (_disposed) return;
      busy = false;
      subscribed = false;
      lifetime = false;
      error = 'premium_unavailable';
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    subscribed = false;
    lifetime = false;
    super.dispose();
  }
}
