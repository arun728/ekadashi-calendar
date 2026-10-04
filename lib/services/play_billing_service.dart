import 'premium_http_backend.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'premium_service.dart';

class PremiumPlan {
  const PremiumPlan(this.id, this.price, this.product);
  final String id, price;
  final ProductDetails product;
}

class PlayBillingService extends ChangeNotifier {
  PlayBillingService(this.premium, {InAppPurchase? store}) : _store = store;
  static const subscription = 'ekadashi_premium';
  static const lifetime = 'ekadashi_premium_lifetime';
  final PremiumService premium;
  InAppPurchase? _store;
  InAppPurchase get store => _store ??= InAppPurchase.instance;
  final List<PremiumPlan> plans = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  String? error;
  bool pending = false;
  Future<void>? _processing;
  Future<void> initialize() async {
    if (premium.backend is PremiumHttpBackend &&
        !(premium.backend as PremiumHttpBackend).configured) {
      error = 'premium_unavailable';
      notifyListeners();
      return;
    }
    _subscription ??= store.purchaseStream.listen(
      (values) {
        _processing = (_processing ?? Future<void>.value())
            .then((_) => _process(values))
            .catchError((_) {
              error = 'premium_verification_failed';
              notifyListeners();
            });
      },
      onError: (_) {
        error = 'premium_unavailable';
        notifyListeners();
      },
    );
    try {
      if (!await store.isAvailable()) throw StateError('Store unavailable');
      final result = await store.queryProductDetails({subscription, lifetime});
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
    notifyListeners();
  }

  Future<void> _process(List<PurchaseDetails> values) async {
    for (final purchase in values) {
      if (!{subscription, lifetime}.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          pending = true;
          break;
        case PurchaseStatus.error:
          pending = false;
          error = 'premium_unavailable';
          break;
        case PurchaseStatus.canceled:
          pending = false;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          pending = false;
          // A purchase remains unacknowledged locally until server verification
          // succeeds. Server/restore retries fulfill it durably.
          final verified = await premium.verify(
            purchase.verificationData.serverVerificationData,
            purchase.productID,
          );
          if (verified && purchase.pendingCompletePurchase) {
            await store.completePurchase(purchase);
          }
          error = verified ? null : 'premium_verification_failed';
      }
    }
    notifyListeners();
  }

  Future<void> buy(PremiumPlan plan) async {
    if (!premium.connected ||
        premium.accountId == null ||
        pending ||
        premium.autoRenew ||
        premium.lifetime) {
      return;
    }
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
      final param = GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: premium.accountId,
        offerToken: offer,
      );
      if (!await store.buyNonConsumable(purchaseParam: param)) {
        error = 'premium_unavailable';
      }
    } catch (_) {
      error = 'premium_unavailable';
    }
    notifyListeners();
  }

  Future<void> restore() async {
    try {
      await premium.connect();
      if (premium.connected) {
        await store.restorePurchases(applicationUserName: premium.accountId);
      }
    } catch (_) {
      error = 'premium_unavailable';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
