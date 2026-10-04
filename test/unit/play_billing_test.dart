import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import '../support/premium_fixture.dart';

class Store extends InAppPurchasePlatform {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  List<ProductDetails>? catalog;
  int completions = 0, bought = 0;
  PurchaseParam? param;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails:
        catalog ??
        [
          ProductDetails(
            id: PlayBillingService.lifetime,
            title: 'Lifetime',
            description: 'Lifetime',
            price: '₹999',
            rawPrice: 999,
            currencyCode: 'INR',
          ),
        ],
    notFoundIDs: [],
  );
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completions++;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought++;
    param = purchaseParam;
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
  Future<void> emit(PurchaseStatus status) async {
    updates.add([
      PurchaseDetails(
        productID: PlayBillingService.lifetime,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local-not-trusted',
          serverVerificationData: 'server-receipt',
          source: 'google_play',
        ),
        transactionDate: null,
        status: status,
      )..pendingCompletePurchase = true,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class VerifyFixture extends PremiumFixture {
  bool valid = false;
  @override
  Future<Map<String, dynamic>> verify(String token, String product) async {
    if (!valid) throw StateError('verification failed');
    return super.verify(token, product);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'pending, canceled and failed verification never grant or acknowledge',
    () async {
      final store = Store();
      InAppPurchasePlatform.instance = store;
      final backend = VerifyFixture();
      final premium = PremiumService(backend: backend);
      final billing = PlayBillingService(premium);
      await billing.initialize();
      await store.emit(PurchaseStatus.pending);
      expect(billing.pending, isTrue);
      expect(premium.isPremium, isFalse);
      await store.emit(PurchaseStatus.canceled);
      expect(billing.pending, isFalse);
      await store.emit(PurchaseStatus.purchased);
      expect(premium.isPremium, isFalse);
      expect(store.completions, 0);
      backend.valid = true;
      await store.emit(PurchaseStatus.restored);
      expect(premium.isPremium, isTrue);
      expect(store.completions, 1);
      billing.dispose();
      premium.dispose();
      await store.updates.close();
    },
  );
  test(
    'checkout uses nonconsumable and obfuscated server account; duplicate renewing purchase blocked',
    () async {
      final store = Store();
      InAppPurchasePlatform.instance = store;
      final premium = PremiumService(
        backend: PremiumFixture()..premium = false,
      );
      await premium.connect();
      final billing = PlayBillingService(premium);
      await billing.initialize();
      await billing.buy(billing.plans.single);
      expect(store.bought, 1);
      expect(store.param!.applicationUserName, 'test-only-account');
      premium.autoRenew = true;
      await billing.buy(billing.plans.single);
      expect(store.bought, 1);
      billing.dispose();
      premium.dispose();
      await store.updates.close();
    },
  );
  test(
    'monthly/yearly select base-plan offer tokens and omit introductory offers',
    () async {
      final store = Store();
      InAppPurchasePlatform.instance = store;
      final offers = [
        for (final pair in [
          ('yearly', null, 'year-token'),
          ('monthly', 'intro', 'intro-token'),
          ('monthly', null, 'month-token'),
        ])
          SubscriptionOfferDetailsWrapper(
            basePlanId: pair.$1,
            offerId: pair.$2,
            offerIdToken: pair.$3,
            offerTags: const [],
            pricingPhases: const [
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: '₹99',
                priceAmountMicros: 99000000,
                priceCurrencyCode: 'INR',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
      ];
      store.catalog = GooglePlayProductDetails.fromProductDetails(
        ProductDetailsWrapper(
          description: 'Premium',
          name: 'Premium',
          productId: PlayBillingService.subscription,
          productType: ProductType.subs,
          title: 'Premium',
          subscriptionOfferDetails: offers,
        ),
      );
      final premium = PremiumService(
        backend: PremiumFixture()..premium = false,
      );
      await premium.connect();
      final billing = PlayBillingService(premium);
      await billing.initialize();
      expect(billing.plans.map((p) => p.id), ['monthly', 'yearly']);
      await billing.buy(billing.plans.first);
      expect(
        (store.param as GooglePlayPurchaseParam).offerToken,
        'month-token',
      );
      await billing.buy(billing.plans.last);
      expect((store.param as GooglePlayPurchaseParam).offerToken, 'year-token');
      billing.dispose();
      premium.dispose();
      await store.updates.close();
    },
  );
  test(
    'active canceled or earned premium never opens a duplicate checkout',
    () async {
      final store = Store();
      InAppPurchasePlatform.instance = store;
      final premium = PremiumService(backend: PremiumFixture());
      await premium.connect();
      expect(premium.isPremium, isTrue);
      expect(premium.autoRenew, isFalse);
      final billing = PlayBillingService(premium);
      await billing.initialize();
      await billing.buy(billing.plans.single);
      expect(store.bought, 0);
      billing.dispose();
      premium.dispose();
      await store.updates.close();
    },
  );
}
