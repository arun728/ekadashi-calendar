import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ekadashi_calendar/services/premium_http_backend.dart';

void main() {
  test(
    'HTTPS session and purchase requests use verified identity, expected account and no redirects',
    () async {
      final calls = <http.Request>[];
      final backend = PremiumHttpBackend(
        baseUrl: 'https://api.example.test',
        identityToken: (interactive) async => 'test-id-token',
        client: MockClient((request) async {
          calls.add(request);
          return http.Response(
            jsonEncode({'coins': 10, 'premium': false}),
            200,
          );
        }),
      );
      await backend.session();
      await backend.verify('play-receipt', 'ekadashi_premium');
      await backend.record({
        'uid': 'ekadashi:2026:01',
        'status': 'observed',
        'mutationKey': 'stable',
      }, expectedAccount: 'account-one');
      expect(calls.map((r) => r.url.path), [
        '/v1/session',
        '/v1/purchases/verify',
        '/v1/observances',
      ]);
      expect(
        calls.every(
          (r) =>
              r.headers['Authorization'] == 'Bearer test-id-token' &&
              !r.followRedirects,
        ),
        isTrue,
      );
      expect(calls.last.headers['X-Expected-App-Account'], 'account-one');
      expect(jsonDecode(calls[1].body), {
        'purchaseToken': 'play-receipt',
        'productId': 'ekadashi_premium',
      });
    },
  );
  for (final status in [302, 401, 409, 422, 503]) {
    test('HTTP $status fails closed', () async {
      final backend = PremiumHttpBackend(
        baseUrl: 'https://api.example.test',
        identityToken: (_) async => 'test-id-token',
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(backend.wallet(), throwsStateError);
    });
  }
  test('missing identity or insecure endpoint sends nothing', () async {
    var count = 0;
    final client = MockClient((_) async {
      count++;
      return http.Response('{}', 200);
    });
    final insecure = PremiumHttpBackend(
      baseUrl: 'http://api.example.test',
      identityToken: (_) async => 'test-id-token',
      client: client,
    );
    await expectLater(insecure.session(), throwsStateError);
    expect(count, 0);
    final anonymous = PremiumHttpBackend(
      baseUrl: 'https://api.example.test',
      identityToken: (_) async => null,
      client: client,
    );
    await expectLater(anonymous.session(), throwsStateError);
    expect(count, 0);
  });
}
