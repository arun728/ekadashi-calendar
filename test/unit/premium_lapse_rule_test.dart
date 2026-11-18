import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/premium_fixture.dart';

/// Arun (16 Nov 2026): when a subscription has expired, remove the Google
/// events Premium synced at once; when in doubt (Play may be holding the
/// subscription while it retries a failed payment), keep them, for at most
/// 57 days. Play gives the device no expiry signal, so what Play last showed
/// decides: cancelled then gone, or Lifetime gone, is confirmed; renewing
/// then gone waits 57 days.
void main() {
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 16, 10);
  });

  PremiumService service(PremiumFixture source) {
    final premium = PremiumService(entitlements: source, now: () => now);
    addTearDown(premium.dispose);
    return premium;
  }

  test(
    'a cancelled subscription that disappears has expired: remove at once',
    () async {
      final source = PremiumFixture()..renewing = false;
      final premium = service(source);
      await premium.refresh();
      expect(premium.subscriptionCancelled, isTrue);
      expect(premium.canRemovePremiumImports, isFalse);
      source.premium = false;
      await premium.refresh();
      expect(premium.lapsed, isTrue);
      expect(premium.canRemovePremiumImports, isTrue);
    },
  );

  test('a renewing subscription that disappears is kept for 57 days', () async {
    final source = PremiumFixture()..renewing = true;
    final premium = service(source);
    await premium.refresh();
    source.premium = false;
    await premium.refresh();
    expect(premium.lapsed, isTrue);
    expect(
      premium.canRemovePremiumImports,
      isFalse,
      reason: 'possible account hold',
    );
    now = now.add(const Duration(days: 56, hours: 23));
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isFalse);
    now = now.add(const Duration(hours: 1));
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isTrue);
    expect(PremiumService.accountHoldWindow, const Duration(days: 57));
  });

  test('coming back within 57 days restarts the clock', () async {
    final source = PremiumFixture()..renewing = true;
    final premium = service(source);
    await premium.refresh();
    source.premium = false;
    await premium.refresh();
    now = now.add(const Duration(days: 56));
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isFalse);
    source.premium = true;
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isFalse);
    now = now.add(const Duration(days: 1));
    source.premium = false;
    await premium.refresh();
    now = now.add(const Duration(days: 5));
    await premium.refresh();
    expect(
      premium.canRemovePremiumImports,
      isFalse,
      reason: 'only 5 days since the second absence began',
    );
    now = now.add(const Duration(days: 52));
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isTrue);
  });

  test('a refunded lifetime purchase is removed at once', () async {
    final source = PremiumFixture()
      ..premium = false
      ..lifetime = true;
    final premium = service(source);
    await premium.refresh();
    expect(premium.lifetime, isTrue);
    source.lifetime = false;
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isTrue);
  });

  test('Play being unreachable never starts the clock', () async {
    final source = PremiumFixture()..renewing = true;
    final premium = service(source);
    await premium.refresh();
    source.fail = true;
    await premium.refresh();
    now = now.add(const Duration(days: 10));
    await premium.refresh();
    expect(premium.lapsed, isFalse);
    expect(premium.canRemovePremiumImports, isFalse);
    source
      ..fail = false
      ..premium = false;
    await premium.refresh();
    expect(
      premium.canRemovePremiumImports,
      isFalse,
      reason: 'the absence starts when Play first answers without it',
    );
    now = now.add(const Duration(days: 57));
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isTrue);
  });

  test('the 57-day clock survives a restart', () async {
    final source = PremiumFixture()..renewing = true;
    final first = service(source);
    await first.refresh();
    source.premium = false;
    await first.refresh();
    now = now.add(const Duration(days: 57));
    final restarted = service(source);
    await restarted.refresh();
    expect(restarted.canRemovePremiumImports, isTrue);
  });

  test('with no history (a reinstall), an absence waits 57 days', () async {
    final source = PremiumFixture()..premium = false;
    final premium = service(source);
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isFalse);
    now = now.add(const Duration(days: 57));
    await premium.refresh();
    expect(premium.canRemovePremiumImports, isTrue);
  });
}
