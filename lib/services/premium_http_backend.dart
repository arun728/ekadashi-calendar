import 'dart:convert';
import 'package:http/http.dart' as http;
import 'google_identity.dart';
import 'premium_service.dart';

class PremiumHttpBackend implements PremiumBackend {
  PremiumHttpBackend({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function(bool interactive)? identityToken,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       base = baseUrl ?? const String.fromEnvironment('PREMIUM_API_URL'),
       _identityToken = identityToken ?? _googleToken,
       _identityConfigured =
           identityToken != null || AppGoogleIdentity.serverClientId.isNotEmpty;
  final http.Client _client;
  final String base;
  final Duration requestTimeout;
  final Future<String?> Function(bool interactive) _identityToken;
  final bool _identityConfigured;
  static const privacyUrl = String.fromEnvironment('PREMIUM_PRIVACY_URL');
  static const termsUrl = String.fromEnvironment('PREMIUM_TERMS_URL');
  static const deletionUrl = String.fromEnvironment('PREMIUM_DELETION_URL');
  static bool validHttps(String value) =>
      Uri.tryParse(value)?.scheme == 'https' &&
      (Uri.tryParse(value)?.host.isNotEmpty ?? false);
  bool get configured =>
      validHttps(base) &&
      _identityConfigured &&
      validHttps(privacyUrl) &&
      validHttps(termsUrl) &&
      validHttps(deletionUrl);
  static Future<String?> _googleToken(bool interactive) async {
    final signIn = AppGoogleIdentity.signIn;
    final user =
        signIn.currentUser ??
        await signIn.signInSilently() ??
        (interactive ? await signIn.signIn() : null);
    return user == null ? null : (await user.authentication).idToken;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool interactive = false,
    String? expectedAccount,
  ]) async {
    if (!validHttps(base) || !_identityConfigured) {
      throw StateError('Premium not configured');
    }
    final token = await _identityToken(interactive);
    if (token == null) throw StateError('Verified identity required');
    final request = http.Request(
      method,
      Uri.parse('${base.replaceFirst(RegExp(r"/+$"), "")}$path'),
    )..followRedirects = false;
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      if (expectedAccount != null) 'X-Expected-App-Account': expectedAccount,
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(requestTimeout);
    if (response.statusCode == 409) {
      throw StateError('Reward conflict; retry requires review');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Premium service unavailable');
    }
    return response.body.isEmpty
        ? {}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> session({bool interactive = true}) =>
      _request('GET', '/v1/session', null, interactive);
  @override
  Future<Map<String, dynamic>> verify(String token, String product) => _request(
    'POST',
    '/v1/purchases/verify',
    {'purchaseToken': token, 'productId': product},
  );
  @override
  Future<Map<String, dynamic>> wallet() => _request('GET', '/v1/wallet');
  @override
  Future<Map<String, dynamic>> record(
    Map<String, dynamic> body, {
    String? expectedAccount,
  }) => _request('POST', '/v1/observances', body, false, expectedAccount);
  @override
  Future<Map<String, dynamic>> redeem(String key, {String? expectedAccount}) =>
      _request(
        'POST',
        '/v1/rewards/redeem',
        {'mutationKey': key},
        false,
        expectedAccount,
      );
  @override
  Future<void> deleteAccount({String? expectedAccount}) async {
    await _request('DELETE', '/v1/account', null, false, expectedAccount);
  }
}
