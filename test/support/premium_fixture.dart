import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';

/// Explicit test-only server/store fixture, never used by a production screen.
class PremiumFixture implements PremiumBackend {
  bool premium = true;
  @override
  Future<Map<String, dynamic>> session({bool interactive = true}) async => {
    'accountId': 'test-only-account',
    'premium': premium,
    'serverTime': '2026-10-04T00:00:00Z',
    'validUntil': '2027-10-04T00:00:00Z',
    'autoRenew': false,
  };
  @override
  Future<Map<String, dynamic>> verify(String token, String product) async => {
    'acknowledged': true,
    ...await session(),
  };
  @override
  Future<Map<String, dynamic>> wallet() async => {
    'coins': 0,
    'observances': {},
  };
  @override
  Future<Map<String, dynamic>> record(
    Map<String, dynamic> body, {
    String? expectedAccount,
  }) async => {};
  @override
  Future<Map<String, dynamic>> redeem(
    String key, {
    String? expectedAccount,
  }) async => session();
  @override
  Future<void> deleteAccount({String? expectedAccount}) async {}
}

class FixtureBilling extends PlayBillingService {
  FixtureBilling(super.premium);
  @override
  Future<void> initialize() async {
    plans.clear();
    for (final entry in {
      'monthly': '₹99',
      'yearly': '₹399',
      'lifetime': '₹999',
    }.entries) {
      plans.add(
        PremiumPlan(
          entry.key,
          entry.value,
          ProductDetails(
            id: entry.key,
            title: entry.key,
            description: entry.key,
            price: entry.value,
            rawPrice: 1,
            currencyCode: 'INR',
          ),
        ),
      );
    }
    notifyListeners();
  }
}
