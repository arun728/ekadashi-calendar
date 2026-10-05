import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';

/// Test-only stand-in for what Google Play Billing reports as owned.
class PremiumFixture implements PlayEntitlementSource {
  bool premium = true;
  bool lifetime = false;
  bool fail = false;
  int queries = 0;
  @override
  Future<Set<String>> ownedProducts() async {
    queries++;
    if (fail) throw StateError('Google Play unavailable');
    return {
      if (premium) PremiumService.subscriptionId,
      if (lifetime) PremiumService.lifetimeId,
    };
  }
}

class FixtureBilling extends PlayBillingService {
  FixtureBilling(super.premium);
  @override
  Future<void> initialize() async {
    plans.clear();
    for (final entry in {
      'monthly': '₹99',
      'yearly': '₹499',
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
