import 'dart:convert';
import 'package:http/http.dart' as http;
import 'google_identity.dart';
import 'premium_service.dart';

class PremiumHttpBackend implements PremiumBackend {
  PremiumHttpBackend({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      base = baseUrl ?? const String.fromEnvironment('PREMIUM_API_URL');
  final http.Client _client;
  final String base;
  static const privacyUrl = String.fromEnvironment('PREMIUM_PRIVACY_URL');
  static const termsUrl = String.fromEnvironment('PREMIUM_TERMS_URL');
  static const deletionUrl = String.fromEnvironment('PREMIUM_DELETION_URL');
  static bool validHttps(String value) =>
      Uri.tryParse(value)?.scheme == 'https' &&
      (Uri.tryParse(value)?.host.isNotEmpty ?? false);
  bool get configured =>
      validHttps(base) &&
      AppGoogleIdentity.serverClientId.isNotEmpty &&
      validHttps(privacyUrl) &&
      validHttps(termsUrl) &&
      validHttps(deletionUrl);
  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool interactive = false,
  ]) async {
    final uri = Uri.tryParse(base);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        AppGoogleIdentity.serverClientId.isEmpty) {
      throw StateError('Premium not configured');
    }
    final signIn = AppGoogleIdentity.signIn;
    final user =
        signIn.currentUser ??
        await signIn.signInSilently() ??
        (interactive ? await signIn.signIn() : null);
    if (user == null) throw StateError('Sign-in required');
    final token = (await user.authentication).idToken;
    if (token == null) throw StateError('Verified identity required');
    final request = http.Request(
      method,
      Uri.parse('${base.replaceFirst(RegExp(r"/+$"), "")}$path'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 20)),
    );
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
  Future<Map<String, dynamic>> record(Map<String, dynamic> body) =>
      _request('POST', '/v1/observances', body);
  @override
  Future<Map<String, dynamic>> redeem(String key) =>
      _request('POST', '/v1/rewards/redeem', {'mutationKey': key});
  @override
  Future<void> deleteAccount() async {
    await _request('DELETE', '/v1/account');
  }
}
