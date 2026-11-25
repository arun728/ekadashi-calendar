import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'premium_service.dart';

/// The store's localized price, shown as the App Store does: a whole price
/// without zero decimals (₹99, not ₹99.00); a price with cents keeps them.
String storePrice(String price, num rawPrice) {
  if (rawPrice != rawPrice.truncate()) return price;
  return price.replaceFirst(RegExp(r'[.,]0+(?=\D*$)'), '');
}

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

// A stream event and an ownership refresh may see the same purchase together.
final _acknowledgements = <String, Future<void>>{};

Future<void> _acknowledgePlayPurchase(
  InAppPurchase store,
  PurchaseDetails purchase,
) async {
  final token = purchase.verificationData.serverVerificationData;
  final running = _acknowledgements[token];
  if (running != null) return running;
  final attempt = _retryPlayAcknowledgement(store, purchase);
  _acknowledgements[token] = attempt;
  try {
    await attempt;
  } finally {
    _acknowledgements.remove(token);
  }
}

Future<void> _retryPlayAcknowledgement(
  InAppPurchase store,
  PurchaseDetails purchase,
) async {
  const transient = {
    BillingResponse.serviceDisconnected,
    BillingResponse.serviceTimeout,
    BillingResponse.serviceUnavailable,
    BillingResponse.networkError,
  };
  for (var attempt = 0; ; attempt++) {
    final platform = InAppPurchasePlatform.instance;
    // The Android API explicitly returns the Play acknowledgement result.
    final Future<Object?> completion = platform is InAppPurchaseAndroidPlatform
        ? platform.completePurchase(purchase)
        : store.completePurchase(purchase);
    final result = await completion;
    if (result is! BillingResultWrapper ||
        result.responseCode == BillingResponse.ok) {
      return;
    }
    if (attempt == 2 || !transient.contains(result.responseCode)) {
      throw StateError('Play acknowledgement: ${result.responseCode.name}');
    }
    await Future<void>.delayed(Duration(milliseconds: 250 << attempt));
  }
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
           ((purchase) =>
               _acknowledgePlayPurchase(InAppPurchase.instance, purchase));

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
  String? subscriptionPurchaseToken;
  GooglePlayPurchaseDetails? subscriptionPurchase;

  @override
  Future<Map<String, DateTime?>> ownedProducts() async {
    final owned = <String, DateTime?>{};
    final renewing = <String, bool>{};
    final subscriptions = <String, GooglePlayPurchaseDetails>{};
    for (final purchase in await _query()) {
      if (!(PremiumService.subscriptionIds.contains(purchase.productID) ||
              purchase.productID == PremiumService.lifetimeId) ||
          !isCompletedPlayPurchase(purchase)) {
        continue;
      }
      owned[purchase.productID] = playPurchaseTime(purchase);
      if (purchase is GooglePlayPurchaseDetails) {
        // A scheduled Yearly to Monthly switch keeps auto-renewing; Play
        // reports "not renewing" only once the user cancels (checked on the
        // M52, 25 Nov 2026), so that is a cancellation, as on iOS.
        if (PremiumService.subscriptionIds.contains(purchase.productID)) {
          renewing[purchase.productID] =
              purchase.billingClientPurchase.isAutoRenewing;
          subscriptions[purchase.productID] = purchase;
        }
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _acknowledge(purchase);
        } catch (error) {
          // The purchase is still owned. The next store read will retry it.
          debugPrint('Google Play acknowledgement failed: $error');
        }
      }
    }
    autoRenewing = renewing;
    subscriptionPurchase =
        subscriptions[PremiumService.ownedSubscriptionId(
          owned.keys.toSet(),
          owned,
        )];
    subscriptionPurchaseToken =
        subscriptionPurchase?.billingClientPurchase.purchaseToken;
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
  static const monthly = PremiumService.monthlySubscriptionId;
  static const yearly = PremiumService.yearlySubscriptionId;
  static const lifetime = PremiumService.lifetimeId;

  static Uri managementUrl(String? activeProductId) =>
      Uri.https('play.google.com', '/store/account/subscriptions', {
        'package': 'com.applausestudios.ekadashi_calendar',
        'sku': activeProductId ?? subscription,
      });
  final PremiumService premium;
  InAppPurchase? _store;
  InAppPurchase get store => _store ??= InAppPurchase.instance;
  final List<PremiumPlan> plans = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  String? error;
  bool pending = false;
  bool _launchingCheckout = false;
  Future<void>? _processing;

  // Play ownership reports the subscription product ID, not the base plan.
  // Use a completed checkout's choice only for the same purchase token.
  String? _currentPlanId;
  String? _planPurchaseToken;
  static const _verifiedPlanKey = 'premium_verified_plan_v1';
  SharedPreferences? _preferences;

  static String _fingerprint(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  String? get currentPlanId {
    if (!premium.subscribed) return null;
    if (premium.subscriptionProductId == monthly) return 'monthly';
    if (premium.subscriptionProductId == yearly) return 'yearly';
    final token = premium.subscriptionPurchaseToken;
    if (token == _planPurchaseToken && _currentPlanId != null) {
      return _currentPlanId;
    }
    if (token == null) return null;
    final stored = _preferences?.getString(_verifiedPlanKey)?.split(':');
    if (stored == null ||
        stored.length != 2 ||
        stored.last != _fingerprint(token)) {
      return null;
    }
    return switch (stored.first) {
      'monthly' || 'yearly' => stored.first,
      _ => null,
    };
  }

  @visibleForTesting
  set currentPlanId(String? value) {
    _currentPlanId = value;
    _planPurchaseToken = premium.subscriptionPurchaseToken;
  }

  String? _requestedPlan;
  DateTime? _requestedAt;
  ({String productId, String token})? _requestedDeferredSwitch;
  String? _scheduledMonthlyToken;
  static const _scheduledMonthlyKey = 'premium_scheduled_monthly_v1';

  /// Yearly is switching to Monthly at renewal. Play's purchase data does not
  /// say so, so the confirmed switch is remembered with its purchase token
  /// (kept across launches). Cancelling in Play drops the switch.
  bool get monthlySwitchScheduled {
    if (currentPlanId != 'yearly' || premium.subscriptionCancelled) {
      return false;
    }
    final token = premium.subscriptionPurchaseToken;
    if (token == null) return false;
    if (_scheduledMonthlyToken != null) return _scheduledMonthlyToken == token;
    return _preferences?.getString(_scheduledMonthlyKey) == _fingerprint(token);
  }

  /// Like other subscription apps, a subscriber can still switch between
  /// monthly and yearly or buy lifetime; lifetime owners need nothing more.
  /// A cancelled subscriber may also reactivate their current plan.
  bool canBuy(PremiumPlan plan) {
    if (pending || premium.lifetime) return false;
    if (plan.id == 'lifetime' || !premium.subscribed) return true;
    if (plan.id == 'monthly' && monthlySwitchScheduled) return false;
    final current = currentPlanId;
    if (current == null) return false;
    if (plan.id == current) return premium.subscriptionCancelled;
    if (plan.id == 'monthly' && plan.product.id == subscription) return false;
    return true;
  }

  Future<void> initialize() async {
    if (_disposed) return;
    try {
      _preferences ??= await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('Play plan preference unavailable: $error');
    }
    if (_disposed) return;
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
      final result = await store.queryProductDetails({
        ...PremiumService.subscriptionIds,
        lifetime,
      });
      if (_disposed) return;
      if (result.error != null) throw StateError('Store unavailable');
      final catalog = <String, PremiumPlan>{};
      for (final product in result.productDetails) {
        if (product.id == lifetime) {
          catalog['lifetime'] = PremiumPlan(
            'lifetime',
            storePrice(product.price, product.rawPrice),
            product,
          );
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
          final id = offer.basePlanId;
          final separate = product.id == (id == 'monthly' ? monthly : yearly);
          if (separate ||
              (product.id == subscription && !catalog.containsKey(id))) {
            catalog[id] = PremiumPlan(
              id,
              storePrice(product.price, product.rawPrice),
              product,
            );
          }
        }
      }
      plans
        ..clear()
        ..addAll(
          [
            'monthly',
            'yearly',
            'lifetime',
          ].map((id) => catalog[id]).whereType<PremiumPlan>(),
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
      if (!(PremiumService.subscriptionIds.contains(purchase.productID) ||
          purchase.productID == lifetime)) {
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          pending = true;
          break;
        case PurchaseStatus.error:
          _requestedPlan = null;
          _requestedAt = null;
          _requestedDeferredSwitch = null;
          pending = false;
          error = 'premium_unavailable';
          debugPrint(
            'Google Play purchase error: ${purchase.error?.code} '
            '${purchase.error?.message} ${purchase.error?.details}',
          );
          break;
        case PurchaseStatus.canceled:
          _requestedPlan = null;
          _requestedAt = null;
          _requestedDeferredSwitch = null;
          pending = false;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (!isCompletedPlayPurchase(purchase)) {
            pending = true;
            break;
          }
          pending = false;
          final purchasedAt = playPurchaseTime(purchase);
          final token = purchase is GooglePlayPurchaseDetails
              ? purchase.billingClientPurchase.purchaseToken
              : null;
          final deferred = _requestedDeferredSwitch;
          final scheduled =
              deferred != null &&
              purchase.status == PurchaseStatus.purchased &&
              purchase.productID == deferred.productId &&
              token != null &&
              token != deferred.token;
          if (scheduled) {
            _scheduledMonthlyToken = token;
            _requestedDeferredSwitch = null;
            try {
              await _preferences?.setString(
                _scheduledMonthlyKey,
                _fingerprint(token),
              );
            } catch (error) {
              debugPrint('Scheduled plan could not be saved: $error');
            }
          }
          final verifiedLegacyCheckout =
              purchase.productID == subscription &&
              purchase.status == PurchaseStatus.purchased &&
              token != null &&
              purchasedAt != null &&
              _requestedAt != null &&
              !purchasedAt.isBefore(_requestedAt!);
          if (verifiedLegacyCheckout ||
              (scheduled && purchase.productID == subscription)) {
            final plan = scheduled ? 'yearly' : _requestedPlan;
            _currentPlanId = plan;
            _planPurchaseToken = token;
            _requestedPlan = null;
            _requestedAt = null;
            if (plan != null) {
              try {
                await _preferences?.setString(
                  _verifiedPlanKey,
                  '$plan:${_fingerprint(token)}',
                );
              } catch (error) {
                debugPrint('Play plan preference could not be saved: $error');
              }
            }
          }
          premium.grant(
            purchase.productID,
            purchasedAt: purchasedAt,
            subscriptionToken: token,
          );
          if (purchase.pendingCompletePurchase) {
            try {
              await _acknowledgePlayPurchase(store, purchase);
            } catch (failure) {
              debugPrint('Google Play acknowledgement failed: $failure');
              error = 'premium_unavailable';
              break;
            }
          }
          error = null;
      }
    }
    _notify();
  }

  Future<void> buy(PremiumPlan plan) async {
    if (_launchingCheckout || !canBuy(plan)) return;
    _launchingCheckout = true;
    try {
      final product = plan.product;
      final source = premium.entitlements;
      if (plan.id != 'lifetime' && source is PlayStoreEntitlements) {
        await premium.refresh();
        if (premium.error != null) {
          throw StateError('Play ownership could not be checked');
        }
        if (_disposed || !canBuy(plan)) return;
      }
      String? offer;
      if (product is GooglePlayProductDetails &&
          product.subscriptionIndex != null) {
        offer = product
            .productDetails
            .subscriptionOfferDetails![product.subscriptionIndex!]
            .offerIdToken;
      }
      ChangeSubscriptionParam? change;
      _requestedDeferredSwitch = null;
      final currentProduct = premium.subscriptionProductId;
      if (currentProduct != null &&
          product.id != lifetime &&
          product.id != currentProduct) {
        if (currentPlanId == plan.id) return;
        final existing = source is PlayStoreEntitlements
            ? source.subscriptionPurchase
            : null;
        if (existing == null || existing.productID != currentProduct) {
          throw StateError('The active Play plan could not be verified');
        }
        change = ChangeSubscriptionParam(
          oldPurchaseDetails: existing,
          replacementMode: plan.id == 'monthly'
              ? ReplacementMode.deferred
              : ReplacementMode.chargeFullPrice,
        );
        if (change.replacementMode == ReplacementMode.deferred) {
          _requestedDeferredSwitch = (
            productId: existing.productID,
            token: existing.billingClientPurchase.purchaseToken,
          );
        }
      }
      _requestedPlan = product.id == subscription ? plan.id : null;
      _requestedAt = _requestedPlan == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              DateTime.now().millisecondsSinceEpoch,
            );
      final param = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: offer,
        changeSubscriptionParam: change,
      );
      if (!await store.buyNonConsumable(purchaseParam: param)) {
        _requestedPlan = null;
        _requestedAt = null;
        _requestedDeferredSwitch = null;
        error = 'premium_unavailable';
      }
    } catch (e) {
      _requestedPlan = null;
      _requestedAt = null;
      _requestedDeferredSwitch = null;
      debugPrint('Google Play checkout failed: $e');
      error = 'premium_unavailable';
    } finally {
      _launchingCheckout = false;
      _notify();
    }
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
