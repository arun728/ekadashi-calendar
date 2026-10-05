import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import '../support/premium_fixture.dart';

class DelayedSource implements PlayEntitlementSource {
  final response = Completer<Set<String>>();
  @override
  Future<Set<String>> ownedProducts() => response.future;
}

void main() {
  test('nothing owned in Google Play means the free tier', () async {
    final service = PremiumService(
      entitlements: PremiumFixture()..premium = false,
    );
    await service.refresh();
    expect(service.isPremium, isFalse);
    expect(service.error, isNull);
    service.dispose();
  });

  test('an active subscription or lifetime purchase unlocks premium', () async {
    final source = PremiumFixture();
    final service = PremiumService(entitlements: source);
    await service.refresh();
    expect(service.isPremium, isTrue);
    expect(service.lifetime, isFalse);
    source
      ..premium = false
      ..lifetime = true;
    await service.refresh();
    expect(service.isPremium, isTrue);
    expect(service.lifetime, isTrue);
    service.dispose();
  });

  test('an expired or refunded subscription is revoked on refresh', () async {
    final source = PremiumFixture();
    final service = PremiumService(entitlements: source);
    await service.refresh();
    expect(service.isPremium, isTrue);
    source.premium = false;
    await service.refresh();
    expect(service.isPremium, isFalse);
    service.dispose();
  });

  test('a Play query failure fails closed and keeps free features', () async {
    final service = PremiumService(entitlements: PremiumFixture()..fail = true);
    await service.refresh();
    expect(service.isPremium, isFalse);
    expect(service.error, 'premium_unavailable');
    service.dispose();
  });

  test('unrelated product IDs never unlock premium', () async {
    final service = PremiumService(entitlements: PremiumFixture());
    service.applyOwned({'some_other_product'});
    expect(service.isPremium, isFalse);
    service.applyOwned({PremiumService.subscriptionId});
    expect(service.isPremium, isTrue);
    service.dispose();
  });

  test('closing during a Play query does not grant after disposal', () async {
    final source = DelayedSource();
    final service = PremiumService(entitlements: source);
    final request = service.refresh();
    service.dispose();
    source.response.complete({PremiumService.lifetimeId});
    await request;
    expect(service.isPremium, isFalse);
  });
}
