import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'premium_service.dart';

class PremiumPlan {
  const PremiumPlan(this.id, this.price, this.product);
  final String id, price;
  final ProductDetails product;
}

/// True only for purchases Google Play reports as PURCHASED. The Android
/// plugin labels every restored purchase "restored", including pending ones,
/// so the Play purchase state is checked directly when it is available.
bool isCompletedPlayPurchase(PurchaseDetails purchase) {
  if (purchase is GooglePlayPurchaseDetails) {
    return purchase.billingClientPurchase.purchaseState ==
        PurchaseStateWrapper.purchased;
  }
  return purchase.status == PurchaseStatus.purchased ||
      purchase.status == PurchaseStatus.restored;
}

/// When Google Play says [purchase] was made (for a subscription, the
/// original purchase; renewals keep it), or null when unknown.
DateTime? playPurchaseTime(PurchaseDetails purchase) {
  if (purchase is GooglePlayPurchaseDetails) {
    return DateTime.fromMillisecondsSinceEpoch(
      purchase.billingClientPurchase.purchaseTime,
    );
  }
  final millis = int.tryParse(purchase.transactionDate ?? '');
  return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
}

/// Reads owned purchases from Google Play Billing on this device and
/// acknowledges any completed purchase Play still holds unacknowledged
/// (Play refunds purchases left unacknowledged for three days).
class PlayStoreEntitlements extends PlayEntitlementSource {
  PlayStoreEntitlements({
    Future<List<PurchaseDetails>> Function()? query,
    Future<void> Function(PurchaseDetails purchase)? acknowledge,
  }) : _query = query ?? _queryPlay,
       // Resolve the store lazily: creating it connects to Play Billing.
       _acknowledge =
           acknowledge ??
           ((purchase) => InAppPurchase.instance.completePurchase(purchase));

  final Future<List<PurchaseDetails>> Function() _query;
  final Future<void> Function(PurchaseDetails purchase) _acknowledge;

  static Future<List<PurchaseDetails>> _queryPlay() async {
    final addition = InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) {
      throw StateError('Google Play purchases unavailable');
    }
    return response.pastPurchases;
  }

  @override
  Map<String, bool> autoRenewing = const {};

  @override
  Future<Map<String, DateTime?>> ownedProducts() async {
    final owned = <String, DateTime?>{};
    final renewing = <String, bool>{};
    for (final purchase in await _query()) {
      if (!{
            PremiumService.subscriptionId,
            PremiumService.lifetimeId,
          }.contains(purchase.productID) ||
          !isCompletedPlayPurchase(purchase)) {
        continue;
      }
      owned[purchase.productID] = playPurchaseTime(purchase);
      if (purchase is GooglePlayPurchaseDetails) {
        renewing[purchase.productID] =
            purchase.billingClientPurchase.isAutoRenewing;
      }
      if (purchase.pendingCompletePurchase) await _acknowledge(purchase);
    }
    autoRenewing = renewing;
    return owned;
  }
}

enum RestoreResult { restored, none, unavailable }

class PlayBillingService extends ChangeNotifier {
  PlayBillingService(this.premium, {InAppPurchase? store}) : _store = store;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static const subscription = PremiumService.subscriptionId;
  static const lifetime = PremiumService.lifetimeId;
  final PremiumService premium;
  InAppPurchase? _store;
  InAppPurchase get store => _store ??= InAppPurchase.instance;
  final List<PremiumPlan> plans = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  String? error;
  bool pending = false;
  Future<void>? _processing;

  /// The base plan (`monthly`/`yearly`) last bought on this phone. Only a
  /// label hint for the paywall; entitlement always comes from Google Play.
  String? currentPlanId;
  String? _requestedPlan;
  static const planHintKey = 'premium_plan_hint';

  /// Like other subscription apps, a subscriber can still switch between
  /// monthly and yearly or buy lifetime; lifetime owners need nothing more.
  /// A cancelled subscriber may also reactivate their current plan.
  bool canBuy(PremiumPlan plan) {
    if (pending || premium.lifetime) return false;
    if (plan.id == 'lifetime' || !premium.subscribed) return true;
    return plan.id != currentPlanId || premium.subscriptionCancelled;
  }

  Future<void> initialize() async {
    if (_disposed) return;
    try {
      currentPlanId = (await SharedPreferences.getInstance()).getString(
        planHintKey,
      );
    } catch (_) {}
    _subscription ??= store.purchaseStream.listen(
      (values) {
        _processing = (_processing ?? Future<void>.value())
            .then((_) => _process(values))
            .catchError((_) {
              error = 'premium_unavailable';
              _notify();
            });
      },
      onError: (_) {
        error = 'premium_unavailable';
        _notify();
      },
    );
    try {
      if (!await store.isAvailable()) throw StateError('Store unavailable');
      final result = await store.queryProductDetails({subscription, lifetime});
      if (_disposed) return;
      if (result.error != null) throw StateError('Store unavailable');
      plans.clear();
      for (final product in result.productDetails) {
        if (product.id == lifetime) {
          plans.add(PremiumPlan('lifetime', product.price, product));
          continue;
        }
        if (product is GooglePlayProductDetails) {
          final index = product.subscriptionIndex;
          if (index == null) continue;
          final offer = product.productDetails.subscriptionOfferDetails![index];
          // No introductory price without full intro/renewal disclosure.
          if (offer.offerId != null ||
              !['monthly', 'yearly'].contains(offer.basePlanId)) {
            continue;
          }
          plans.add(PremiumPlan(offer.basePlanId, product.price, product));
        }
      }
      plans.sort(
        (a, b) => ['monthly', 'yearly', 'lifetime']
            .indexOf(a.id)
            .compareTo(['monthly', 'yearly', 'lifetime'].indexOf(b.id)),
      );
      error = plans.isEmpty ? 'premium_unavailable' : null;
    } catch (_) {
      error = 'premium_unavailable';
    }
    _notify();
  }

  Future<void> _process(List<PurchaseDetails> values) async {
    for (final purchase in values) {
      debugPrint(
        'Google Play purchase update: ${purchase.productID} '
        '${purchase.status.name} ${purchase.error?.code ?? ''} '
        '${purchase.error?.message ?? ''} ${purchase.error?.details ?? ''}',
      );
      if (!{subscription, lifetime}.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          pending = true;
          break;
        case PurchaseStatus.error:
          pending = false;
          error = 'premium_unavailable';
          debugPrint(
            'Google Play purchase error: ${purchase.error?.code} '
            '${purchase.error?.message} ${purchase.error?.details}',
          );
          break;
        case PurchaseStatus.canceled:
          pending = false;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (!isCompletedPlayPurchase(purchase)) {
            pending = true;
            break;
          }
          pending = false;
          premium.grant(
            purchase.productID,
            purchasedAt: playPurchaseTime(purchase),
          );
          if (purchase.productID == subscription && _requestedPlan != null) {
            currentPlanId = _requestedPlan;
            try {
              await (await SharedPreferences.getInstance()).setString(
                planHintKey,
                _requestedPlan!,
              );
            } catch (_) {}
          }
          if (purchase.pendingCompletePurchase) {
            await store.completePurchase(purchase);
          }
          error = null;
      }
    }
    _notify();
  }

  Future<void> buy(PremiumPlan plan) async {
    if (!canBuy(plan)) return;
    _requestedPlan = plan.id == 'lifetime' ? null : plan.id;
    try {
      final product = plan.product;
      String? offer;
      if (product is GooglePlayProductDetails &&
          product.subscriptionIndex != null) {
        offer = product
            .productDetails
            .subscriptionOfferDetails![product.subscriptionIndex!]
            .offerIdToken;
      }
      // Switching between monthly and yearly (base plans of the same
      // subscription) and reactivating a cancelled plan are plain purchases:
      // Google says to send no SubscriptionUpdateParams; Play replaces the
      // old plan using the Play Console's default replacement mode.
      final param = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: offer,
      );
      if (!await store.buyNonConsumable(purchaseParam: param)) {
        error = 'premium_unavailable';
      }
    } catch (e) {
      debugPrint('Google Play checkout failed: $e');
      error = 'premium_unavailable';
    }
    _notify();
  }

  /// Restores from Google Play's owned purchases; no account sign-in needed.
  /// Google Play also restores automatically at launch and on resume; this
  /// manual check reports what it found so the user gets clear feedback.
  Future<RestoreResult> restore() async {
    await premium.refresh();
    error = premium.error;
    _notify();
    if (premium.error != null) return RestoreResult.unavailable;
    return premium.isPremium ? RestoreResult.restored : RestoreResult.none;
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
