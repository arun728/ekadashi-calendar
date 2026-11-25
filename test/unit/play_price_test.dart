import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import '../support/premium_fixture.dart';

class _PriceStore extends InAppPurchasePlatform {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: PlayBillingService.lifetime,
            title: 'Lifetime',
            description: 'Lifetime',
            price: '₹1,999.00',
            rawPrice: 1999,
            currencyCode: 'INR',
          ),
        ],
        notFoundIDs: const [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Play prices show like the App Store (₹99, not ₹99.00)', () {
    test('whole prices drop zero decimals', () {
      expect(storePrice('₹99.00', 99), '₹99');
      expect(storePrice('₹599.00', 599), '₹599');
      expect(storePrice('₹1,999.00', 1999), '₹1,999');
      expect(storePrice('1.999,00 €', 1999), '1.999 €');
    });

    test('prices with cents keep them', () {
      expect(storePrice(r'$2.99', 2.99), r'$2.99');
      expect(storePrice('₹99.50', 99.5), '₹99.50');
      expect(storePrice('₹99', 99), '₹99');
    });

    test('the plans page gets the short price', () async {
      InAppPurchasePlatform.instance = _PriceStore();
      final billing = PlayBillingService(
        PremiumService(entitlements: PremiumFixture()..premium = false),
      );
      addTearDown(billing.dispose);
      await billing.initialize();
      expect(billing.plans.single.price, '₹1,999');
    });
  });
}
