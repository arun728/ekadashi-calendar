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
  Future<void> restorePurchases({String? applicationUserName}) async {
    restores++;
  }

  int restores = 0;
  Future<void> emit(
    PurchaseStatus status, {
    String product = PlayBillingService.lifetime,
  }) async {
    updates.add([
      PurchaseDetails(
        productID: product,
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

GooglePlayPurchaseDetails playPurchase(
  String product,
  PurchaseStateWrapper state, {
  bool acknowledged = false,
}) => GooglePlayPurchaseDetails.fromPurchase(
  PurchaseWrapper(
    orderId: 'order',
    packageName: 'com.applausestudios.ekadashi_calendar',
    purchaseTime: DateTime(2026, 11, 20).millisecondsSinceEpoch,
    purchaseToken: 'token-$product',
    signature: 'signature',
    products: [product],
    isAutoRenewing: product == PlayBillingService.subscription,
    originalJson: '{}',
    isAcknowledged: acknowledged,
    purchaseState: state,
  ),
).single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'pending, canceled and failed purchases never grant or acknowledge',
    () async {
      final store = Store();
      InAppPurchasePlatform.instance = store;
      final premium = PremiumService(
        entitlements: PremiumFixture()..premium = false,
      );
      final billing = PlayBillingService(premium);
      await billing.initialize();
      await store.emit(PurchaseStatus.pending);
      expect(billing.pending, isTrue);
      expect(premium.isPremium, isFalse);
      await store.emit(PurchaseStatus.canceled);
      expect(billing.pending, isFalse);
      await store.emit(PurchaseStatus.error);
      expect(premium.isPremium, isFalse);
      expect(store.completions, 0);
      billing.dispose();
      premium.dispose();
      await store.updates.close();
    },
  );

  test(
    'a completed Google Play purchase unlocks and is acknowledged',
    () async {
      final store = Store();
      InAppPurchasePlatform.instance = store;
      final premium = PremiumService(
        entitlements: PremiumFixture()..premium = false,
      );
      final billing = PlayBillingService(premium);
      await billing.initialize();
      await store.emit(PurchaseStatus.purchased);
      expect(premium.isPremium, isTrue);
      expect(premium.lifetime, isTrue);
      expect(store.completions, 1);
      expect(billing.error, isNull);
      billing.dispose();
      premium.dispose();
      await store.updates.close();
    },
  );

  test('purchases of other products are ignored', () async {
    final store = Store();
    InAppPurchasePlatform.instance = store;
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
    final billing = PlayBillingService(premium);
    await billing.initialize();
    await store.emit(PurchaseStatus.purchased, product: 'other_product');
    expect(premium.isPremium, isFalse);
    expect(store.completions, 0);
    billing.dispose();
    premium.dispose();
    await store.updates.close();
  });

  test('checkout needs no Google sign-in; duplicates are blocked', () async {
    final store = Store();
    InAppPurchasePlatform.instance = store;
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
    final billing = PlayBillingService(premium);
    await billing.initialize();
    await billing.buy(billing.plans.single);
    expect(store.bought, 1);
    expect(store.param!.applicationUserName, isNull);
    premium.applyOwned({PremiumService.subscriptionId});
    await billing.buy(billing.plans.single);
    expect(store.bought, 1);
    billing.dispose();
    premium.dispose();
    await store.updates.close();
  });

  test('restore re-reads what Google Play owns', () async {
    final store = Store();
    InAppPurchasePlatform.instance = store;
    final source = PremiumFixture()..premium = false;
    final premium = PremiumService(entitlements: source);
    final billing = PlayBillingService(premium);
    await billing.initialize();
    source.premium = true;
    await billing.restore();
    expect(premium.isPremium, isTrue);
    expect(source.queries, 1);
    billing.dispose();
    premium.dispose();
    await store.updates.close();
  });

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
        entitlements: PremiumFixture()..premium = false,
      );
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

  group('owned purchases from Google Play', () {
    test(
      'only PURCHASED premium products count and are acknowledged',
      () async {
        final acknowledged = <String>[];
        final source = PlayStoreEntitlements(
          query: () async => [
            playPurchase(
              PlayBillingService.subscription,
              PurchaseStateWrapper.pending,
            ),
            playPurchase('other_product', PurchaseStateWrapper.purchased),
            playPurchase(
              PlayBillingService.lifetime,
              PurchaseStateWrapper.purchased,
            ),
          ],
          acknowledge: (p) async => acknowledged.add(p.productID),
        );
        expect(await source.ownedProducts(), {
          PlayBillingService.lifetime: DateTime(2026, 11, 20),
        });
        expect(acknowledged, [PlayBillingService.lifetime]);
      },
    );

    test('already acknowledged purchases are not acknowledged again', () async {
      var acknowledgements = 0;
      final source = PlayStoreEntitlements(
        query: () async => [
          playPurchase(
            PlayBillingService.subscription,
            PurchaseStateWrapper.purchased,
            acknowledged: true,
          ),
        ],
        acknowledge: (_) async => acknowledgements++,
      );
      expect(await source.ownedProducts(), {
        PlayBillingService.subscription: DateTime(2026, 11, 20),
      });
      expect(acknowledgements, 0);
    });

    test(
      'a pending Play purchase reported as restored does not unlock',
      () async {
        final store = Store();
        InAppPurchasePlatform.instance = store;
        final premium = PremiumService(
          entitlements: PremiumFixture()..premium = false,
        );
        final billing = PlayBillingService(premium);
        await billing.initialize();
        store.updates.add([
          playPurchase(
            PlayBillingService.subscription,
            PurchaseStateWrapper.pending,
          )..status = PurchaseStatus.restored,
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(premium.isPremium, isFalse);
        expect(store.completions, 0);
        billing.dispose();
        premium.dispose();
        await store.updates.close();
      },
    );
  });
}
