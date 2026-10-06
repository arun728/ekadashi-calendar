import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import '../support/premium_fixture.dart';

PremiumPlan plan(String id) => PremiumPlan(
  id,
  '₹1',
  ProductDetails(
    id: id,
    title: id,
    description: id,
    price: '₹1',
    rawPrice: 1,
    currencyCode: 'INR',
  ),
);

void main() {
  final monthly = plan('monthly'), yearly = plan('yearly');
  final lifetime = plan('lifetime');

  PlayBillingService billingFor(PremiumService premium) {
    final billing = FixtureBilling(premium);
    addTearDown(billing.dispose);
    addTearDown(premium.dispose);
    return billing;
  }

  test('a free user can buy every plan', () {
    final billing = billingFor(
      PremiumService(entitlements: PremiumFixture()..premium = false),
    );
    for (final p in [monthly, yearly, lifetime]) {
      expect(billing.canBuy(p), isTrue, reason: p.id);
    }
  });

  test('a monthly subscriber can upgrade to yearly or lifetime', () {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned({PremiumService.subscriptionId});
    final billing = billingFor(premium)..currentPlanId = 'monthly';
    expect(billing.canBuy(monthly), isFalse);
    expect(billing.canBuy(yearly), isTrue);
    expect(billing.canBuy(lifetime), isTrue);
  });

  test('a subscriber whose plan is unknown on this phone can switch', () {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned({PremiumService.subscriptionId});
    final billing = billingFor(premium);
    for (final p in [monthly, yearly, lifetime]) {
      expect(billing.canBuy(p), isTrue, reason: p.id);
    }
  });

  test('lifetime owners and pending purchases cannot buy again', () {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned({PremiumService.lifetimeId});
    final billing = billingFor(premium);
    for (final p in [monthly, yearly, lifetime]) {
      expect(billing.canBuy(p), isFalse, reason: p.id);
    }
    final free = billingFor(
      PremiumService(entitlements: PremiumFixture()..premium = false),
    )..pending = true;
    expect(free.canBuy(monthly), isFalse);
  });
}
