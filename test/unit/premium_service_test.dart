import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';

class Backend implements PremiumBackend {
  Map<String, dynamic> result = {
    'premium': true,
    'serverTime': '2026-10-04T00:00:00Z',
    'validUntil': '2027-10-04T00:00:00Z',
    'lifetime': false,
  };
  @override
  Future<Map<String, dynamic>> session({bool interactive = true}) async => {
    'accountId': 'account',
    ...result,
  };
  @override
  Future<Map<String, dynamic>> verify(String token, String product) async =>
      result;
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
  }) async => {};
  @override
  Future<void> deleteAccount({String? expectedAccount}) async {}
}

class DelayedBackend extends Backend {
  final response = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> session({bool interactive = true}) =>
      response.future;
}

class SwitchBackend extends Backend {
  final verification = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> verify(String token, String product) =>
      verification.future;
}

class DelayedRedeemBackend extends Backend {
  final redemption = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> redeem(String key, {String? expectedAccount}) =>
      redemption.future;
}

void main() {
  test('no paid flag or unverified receipt grants access', () async {
    final b = Backend();
    final s = PremiumService(backend: b);
    expect(s.isPremium, isFalse);
    b.result = {
      'premium': false,
      'serverTime': '2026-10-04T00:00:00Z',
      'validUntil': null,
    };
    await s.connect();
    expect(s.isPremium, isFalse);
    s.dispose();
  });
  test('verified short lease expires even if device clock changes', () async {
    final b = Backend();
    int elapsed = 0;
    final s = PremiumService(backend: b, elapsedMillis: () => elapsed);
    await s.connect();
    expect(s.isPremium, isTrue);
    elapsed = 300001;
    expect(s.isPremium, isFalse);
    s.dispose();
  });
  test(
    'offline verification fails closed and leaves free tier available',
    () async {
      final b = Backend();
      final s = PremiumService(backend: b);
      b.result = {'premium': true, 'serverTime': 'bad', 'validUntil': 'bad'};
      await s.connect();
      expect(s.isPremium, isFalse);
      expect(s.error, isNotNull);
      s.dispose();
    },
  );
  test(
    'server expiration beats a future local clock-independent lease',
    () async {
      final b = Backend();
      final s = PremiumService(backend: b);
      b.result = {
        'premium': true,
        'serverTime': '2026-10-04T00:00:00Z',
        'validUntil': '2026-10-03T00:00:00Z',
      };
      await s.connect();
      expect(s.isPremium, isFalse);
      s.dispose();
    },
  );
  test(
    'closing premium during verification does not notify or grant after disposal',
    () async {
      final backend = DelayedBackend();
      final service = PremiumService(backend: backend);
      final request = service.connect();
      service.dispose();
      backend.response.complete({'accountId': 'account', ...backend.result});
      await request;
      expect(service.isPremium, isFalse);
      expect(service.accountId, isNull);
    },
  );
  test(
    'old-account verification cannot grant premium after an account switch',
    () async {
      final backend = SwitchBackend();
      backend.result['premium'] = false;
      final service = PremiumService(backend: backend);
      await service.connect();
      final old = service.verify('old-token', 'ekadashi_premium');
      service.reset();
      backend.result['accountId'] = 'new-account';
      await service.connect();
      backend.verification.complete({
        'premium': true,
        'acknowledged': true,
        'serverTime': '2026-10-04T00:00:00Z',
        'validUntil': '2027-10-04T00:00:00Z',
      });
      await old;
      expect(service.accountId, 'new-account');
      expect(service.isPremium, isFalse);
      service.dispose();
    },
  );
  test(
    'old-account redemption response cannot grant after account switch',
    () async {
      final backend = DelayedRedeemBackend();
      backend.result['premium'] = false;
      final service = PremiumService(backend: backend);
      await service.connect();
      final old = service.redeem('old-redemption');
      service.reset();
      backend.result['accountId'] = 'new-account';
      await service.connect();
      backend.redemption.complete({
        'state': 'completed',
        'premium': true,
        'serverTime': '2026-10-04T00:00:00Z',
        'validUntil': '2027-10-04T00:00:00Z',
      });
      await old;
      expect(service.isPremium, isFalse);
      service.dispose();
    },
  );
}
