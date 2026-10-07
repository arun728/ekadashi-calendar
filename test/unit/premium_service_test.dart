import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import '../support/premium_fixture.dart';

class DelayedSource extends PlayEntitlementSource {
  final response = Completer<Map<String, DateTime?>>();
  @override
  Future<Map<String, DateTime?>> ownedProducts() => response.future;
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
    source.response.complete({PremiumService.lifetimeId: null});
    await request;
    expect(service.isPremium, isFalse);
  });

  group('subscription year', () {
    ({DateTime start, DateTime end}) year(DateTime? bought, DateTime now) =>
        PremiumService.subscriptionYear(bought, now);

    test('an annual plan bought in November covers until next October', () {
      final window = year(DateTime(2026, 11, 20), DateTime(2026, 11, 21));
      expect(window.start, DateTime(2026, 11));
      expect(window.end, DateTime(2027, 11));
    });

    test('later in the same subscription year the window is unchanged', () {
      final window = year(DateTime(2026, 11, 20), DateTime(2027, 9, 30));
      expect(window.start, DateTime(2026, 11));
      expect(window.end, DateTime(2027, 11));
    });

    test('after renewal the next subscription year is used', () {
      final window = year(DateTime(2026, 11, 20), DateTime(2027, 11, 2));
      expect(window.start, DateTime(2027, 11));
      expect(window.end, DateTime(2028, 11));
    });

    test('without a purchase date it starts this month', () {
      final window = year(null, DateTime(2026, 10, 5));
      expect(window.start, DateTime(2026, 10));
      expect(window.end, DateTime(2027, 10));
    });

    test('the service uses the purchase date Google Play reports', () async {
      final service = PremiumService(
        entitlements: PremiumFixture()..purchasedAt = DateTime(2026, 11, 20),
      );
      await service.refresh();
      expect(service.purchasedAt, DateTime(2026, 11, 20));
      expect(
        service.syncWindow(DateTime(2027, 2, 1))!.start,
        DateTime(2026, 11),
      );
      service.dispose();
    });

    test('free users have no premium sync window', () async {
      final service = PremiumService(
        entitlements: PremiumFixture()..premium = false,
      );
      await service.refresh();
      expect(service.syncWindow(DateTime(2026, 10, 5)), isNull);
      service.dispose();
    });
  });

  group('lifetime and lapse', () {
    test('lifetime syncs every calendar year the app has', () {
      final service = PremiumService(entitlements: PremiumFixture());
      service.applyOwned(
        {PremiumService.lifetimeId},
        purchasedAt: {PremiumService.lifetimeId: DateTime(2026, 11, 20)},
      );
      final window = service.syncWindow(
        DateTime(2026, 11, 21),
        calendarYears: (first: 2026, last: 2027),
      )!;
      expect(window.start, DateTime(2026, 1, 1));
      expect(window.end, DateTime(2028, 1, 1));
      service.dispose();
    });

    test('lapsed only once Google Play confirms nothing is owned', () async {
      final source = PremiumFixture();
      final service = PremiumService(entitlements: source);
      expect(service.lapsed, isFalse, reason: 'Not checked with Play yet');
      await service.refresh();
      expect(service.lapsed, isFalse);
      source.fail = true;
      await service.refresh();
      expect(service.isPremium, isFalse);
      expect(
        service.lapsed,
        isFalse,
        reason: 'Play unavailable is not a lapse',
      );
      source
        ..fail = false
        ..premium = false;
      await service.refresh();
      expect(service.lapsed, isTrue);
      service.dispose();
    });
  });
}
