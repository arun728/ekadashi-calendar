import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What Google Play Billing reports as currently owned on this device.
abstract class PlayEntitlementSource {
  /// Product IDs in the PURCHASED state (an active or grace-period
  /// subscription, or the lifetime product) mapped to the purchase time Play
  /// reports, when known. Throws when Play is unavailable.
  Future<Map<String, DateTime?>> ownedProducts();

  /// Whether each owned product renews automatically, from the last
  /// [ownedProducts] call. A cancelled subscription stays owned (and
  /// Premium stays on) until the period already paid for ends.
  Map<String, bool> get autoRenewing => const {};

  String? get subscriptionPurchaseToken => null;

  /// Requires explicit expiry evidence, beyond absence from owned products.
  bool get subscriptionExpiryConfirmed => false;
}

/// Premium access comes only from Google Play's purchase record. It is never
/// persisted locally and is not tied to a Google (Calendar) sign-in.
class PremiumService extends ChangeNotifier {
  PremiumService({required this.entitlements, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const subscriptionId = 'ekadashi_premium';
  static const monthlySubscriptionId = 'ekadashi_premium_monthly';
  static const yearlySubscriptionId = 'ekadashi_premium_yearly';
  static const subscriptionIds = {
    subscriptionId,
    monthlySubscriptionId,
    yearlySubscriptionId,
  };
  static const lifetimeId = 'ekadashi_premium_lifetime';

  final PlayEntitlementSource entitlements;
  final DateTime Function() _now;
  bool _disposed = false;
  Future<void>? _refreshInFlight;
  String? subscriptionPurchaseToken;
  String? subscriptionProductId;
  bool subscribed = false;
  bool lifetime = false;
  bool busy = false;
  String? error;

  /// When the active premium product was bought, as reported by Google Play.
  DateTime? purchasedAt;

  bool get isPremium => subscribed || lifetime;

  static String? ownedSubscriptionId(
    Set<String> owned,
    Map<String, DateTime?> purchasedAt,
  ) {
    String? latest;
    for (final id in subscriptionIds) {
      if (!owned.contains(id)) continue;
      final date = purchasedAt[id];
      final previous = purchasedAt[latest];
      if (latest == null ||
          (date != null && (previous == null || date.isAfter(previous)))) {
        latest = id;
      }
    }
    return latest;
  }

  /// The subscription was cancelled in Google Play but the paid period has
  /// not ended yet, so Premium stays on until it does (Google's rule).
  bool subscriptionCancelled = false;

  bool _confirmedByPlay = false;

  /// Google Play answered and reports no premium product owned (a
  /// subscription ended or a purchase was refunded). False while Play has not
  /// answered or is unreachable, so being offline never counts as a lapse.
  bool get lapsed => _confirmedByPlay && !isPremium;

  /// How long a renewing subscription may be missing before it counts as
  /// expired. Play drops a purchase both during account hold (a failed
  /// renewal it is still retrying) and after expiry, and tells the device
  /// neither, so a subscription that was renewing when last seen is kept
  /// this long. Both live base plans use a 3-day grace period and Play's
  /// default account hold (60 days minus grace). Keep this window in sync
  /// with Play Console if either plan's recovery periods change.
  static const accountHoldWindow = Duration(days: 57);

  static const _historyRenewingKey = 'premium_history_subscription_renewing';
  static const _historyLifetimeKey = 'premium_history_lifetime_owned';
  static const _historyAbsentKey = 'premium_history_absent_since_ms';

  // What Play last showed while Premium was owned, and since when it has been
  // missing (kept across launches).
  bool _historyLoaded = false;
  bool? _lastRenewing;
  bool _lastLifetime = false;
  DateTime? _absentSince;

  /// Premium-synced Google events may be removed: Play answered with nothing
  /// owned and the expiry is confirmed. A cancelled subscription that ended
  /// or a refunded Lifetime is confirmed at once; a subscription that was
  /// renewing (or unknown, after a reinstall) only after [accountHoldWindow].
  bool get canRemovePremiumImports {
    if (!lapsed) return false;
    if (entitlements.subscriptionExpiryConfirmed) return true;
    final since = _absentSince;
    if (since == null) return false;
    if (_lastRenewing == false || _lastLifetime) return true;
    return !_now().isBefore(since.add(accountHoldWindow));
  }

  void _recordOwnership() {
    if (isPremium) {
      _lastRenewing = subscribed ? !subscriptionCancelled : null;
      _lastLifetime = lifetime;
      _absentSince = null;
    } else {
      _absentSince ??= _now();
    }
  }

  Future<void> _loadHistory() async {
    if (_historyLoaded) return;
    _historyLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastRenewing = prefs.getBool(_historyRenewingKey);
      _lastLifetime = prefs.getBool(_historyLifetimeKey) ?? false;
      final absent = prefs.getInt(_historyAbsentKey);
      _absentSince = absent == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(absent);
    } catch (error) {
      debugPrint('Premium history unavailable: $error');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final renewing = _lastRenewing;
      renewing == null
          ? await prefs.remove(_historyRenewingKey)
          : await prefs.setBool(_historyRenewingKey, renewing);
      await prefs.setBool(_historyLifetimeKey, _lastLifetime);
      final absent = _absentSince;
      absent == null
          ? await prefs.remove(_historyAbsentKey)
          : await prefs.setInt(
              _historyAbsentKey,
              absent.millisecondsSinceEpoch,
            );
    } catch (error) {
      debugPrint('Premium history could not be saved: $error');
    }
  }

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
    Map<String, bool> autoRenewing = const {},
    String? subscriptionToken,
  }) {
    if (_disposed) return;
    subscriptionProductId = ownedSubscriptionId(owned, purchasedAt);
    subscribed = subscriptionProductId != null;
    lifetime = owned.contains(lifetimeId);
    subscriptionPurchaseToken = subscribed ? subscriptionToken : null;
    subscriptionCancelled =
        subscribed && autoRenewing[subscriptionProductId] == false;
    _confirmedByPlay = true;
    // The subscription's year governs syncing while it is active.
    this.purchasedAt = subscribed
        ? purchasedAt[subscriptionProductId]
        : lifetime
        ? purchasedAt[lifetimeId]
        : null;
    error = null;
    _recordOwnership();
    _notify();
  }

  /// Adds one completed purchase reported by the Play purchase stream.
  void grant(
    String productId, {
    DateTime? purchasedAt,
    String? subscriptionToken,
  }) {
    if (_disposed) return;
    if (subscriptionIds.contains(productId)) {
      subscribed = true;
      subscriptionProductId = productId;
      subscriptionPurchaseToken = subscriptionToken;
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
  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    final running = _refreshInFlight;
    if (running != null) return running;
    final check = Future<void>.microtask(
      _refreshOwned,
    ).whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = check;
    busy = true;
    _notify();
    return check;
  }

  Future<void> _refreshOwned() async {
    if (_disposed) return;
    try {
      final owned = await entitlements.ownedProducts();
      if (_disposed) return;
      await _loadHistory();
      if (_disposed) return;
      busy = false;
      applyOwned(
        owned.keys.toSet(),
        purchasedAt: owned,
        autoRenewing: entitlements.autoRenewing,
        subscriptionToken: entitlements.subscriptionPurchaseToken,
      );
      await _saveHistory();
    } catch (_) {
      if (_disposed) return;
      busy = false;
      _confirmedByPlay = false;
      subscribed = false;
      lifetime = false;
      subscriptionCancelled = false;
      subscriptionPurchaseToken = null;
      subscriptionProductId = null;
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
