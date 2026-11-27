// SHOTS-ONLY: store screenshot and video helpers. Never shipped.
import 'package:in_app_purchase/in_app_purchase.dart';
import 'services/premium_service.dart';
import 'services/play_billing_service.dart';

const shotsPremium = String.fromEnvironment('SHOTS_PREMIUM'); // '', monthly, yearly

class ShotsEntitlements extends PlayEntitlementSource {
  @override
  Future<Map<String, DateTime?>> ownedProducts() async => shotsPremium.isEmpty
      ? {}
      : {PremiumService.subscriptionId: DateTime(2026, 11, 1, 9)};
}

class ShotsBilling extends PlayBillingService {
  ShotsBilling(super.premium);
  @override
  Future<void> initialize() async {
    currentPlanId = shotsPremium.isEmpty ? null : shotsPremium;
    plans
      ..clear()
      ..addAll([
        for (final id in ['monthly', 'yearly', 'lifetime'])
          PremiumPlan(id, '', ProductDetails(id: id, title: id, description: id, price: '', rawPrice: 1, currencyCode: 'INR')),
      ]);
    notifyListeners();
  }

  @override
  Future<void> buy(PremiumPlan plan) async {}
}
