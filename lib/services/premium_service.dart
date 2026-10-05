import 'package:flutter/foundation.dart';

/// What Google Play Billing reports as currently owned on this device.
abstract interface class PlayEntitlementSource {
  /// Product IDs in the PURCHASED state (an active or grace-period
  /// subscription, or the lifetime product) mapped to the purchase time Play
  /// reports, when known. Throws when Play is unavailable.
  Future<Map<String, DateTime?>> ownedProducts();
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

  /// When the active premium product was bought, as reported by Google Play.
  DateTime? purchasedAt;

  bool get isPremium => subscribed || lifetime;

  bool _confirmedByPlay = false;

  /// Google Play answered and reports no premium product owned (a
  /// subscription ended or a purchase was refunded). False while Play has not
  /// answered or is unreachable, so being offline never counts as a lapse.
  bool get lapsed => _confirmedByPlay && !isPremium;

  /// The 12-month subscription year containing [now], anchored on the month
  /// of [purchasedAt] (a plan bought in November runs November to October).
  /// Without a purchase date it starts in the current month.
  static ({DateTime start, DateTime end}) subscriptionYear(
    DateTime? purchasedAt,
    DateTime now,
  ) {
    final anchor = purchasedAt ?? now;
    final months = (now.year - anchor.year) * 12 + now.month - anchor.month;
    final years = months < 0 ? 0 : months ~/ 12;
    final start = DateTime(anchor.year + years, anchor.month);
    return (start: start, end: DateTime(start.year + 1, start.month));
  }

  /// The Google Calendar range premium may sync now, or null when free.
  /// Lifetime covers every calendar year the app has data for
  /// ([calendarYears]); subscriptions cover the current subscription year.
  ({DateTime start, DateTime end})? syncWindow(
    DateTime now, {
    ({int first, int last})? calendarYears,
  }) {
    if (!isPremium) return null;
    if (lifetime && calendarYears != null) {
      return (
        start: DateTime(calendarYears.first),
        end: DateTime(calendarYears.last + 1),
      );
    }
    return subscriptionYear(purchasedAt, now);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Applies Play's complete owned-product list, revoking anything missing.
  void applyOwned(
    Set<String> owned, {
    Map<String, DateTime?> purchasedAt = const {},
  }) {
    if (_disposed) return;
    subscribed = owned.contains(subscriptionId);
    lifetime = owned.contains(lifetimeId);
    _confirmedByPlay = true;
    // The subscription's year governs syncing while it is active.
    this.purchasedAt = subscribed
        ? purchasedAt[subscriptionId]
        : lifetime
        ? purchasedAt[lifetimeId]
        : null;
    error = null;
    _notify();
  }

  /// Adds one completed purchase reported by the Play purchase stream.
  void grant(String productId, {DateTime? purchasedAt}) {
    if (_disposed) return;
    if (productId == subscriptionId) {
      subscribed = true;
      this.purchasedAt = purchasedAt;
    }
    if (productId == lifetimeId) {
      lifetime = true;
      if (!subscribed) this.purchasedAt = purchasedAt;
    }
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
      applyOwned(owned.keys.toSet(), purchasedAt: owned);
    } catch (_) {
      if (_disposed) return;
      busy = false;
      _confirmedByPlay = false;
      subscribed = false;
      lifetime = false;
      purchasedAt = null;
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
