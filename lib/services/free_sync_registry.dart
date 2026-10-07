import 'dart:convert';
import 'package:http/http.dart' as http;

/// Remembers, per Google account, that the one free Google Calendar sync was
/// used, so reinstalling the app or switching phones cannot reuse it.
abstract interface class FreeSyncRegistry {
  /// Whether the Google account behind [googleIdToken] already used it.
  /// Throws when the registry cannot be reached.
  Future<bool> isUsed(String googleIdToken);

  /// Records the free sync of [month] for that account (first write wins).
  Future<void> record(String googleIdToken, DateTime month);
}

/// A free Cloud Firestore (Firebase Spark plan) document per Google account,
/// over plain HTTPS. The user's existing Google sign-in ID token is exchanged
/// for a Firebase ID token, so there is no extra consent screen, and the
/// security rules in `firebase/firestore.rules` only let an account read or
/// create its own record (never change or delete it).
class FirestoreFreeSyncRegistry implements FreeSyncRegistry {
  FirestoreFreeSyncRegistry({
    required this.apiKey,
    required this.projectId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  /// The registry built into this app, or null when Firebase settings were
  /// not provided at build time (the phone's own record is then used alone).
  static FirestoreFreeSyncRegistry? fromEnvironment() =>
      _apiKey.isEmpty || _projectId.isEmpty
      ? null
      : FirestoreFreeSyncRegistry(apiKey: _apiKey, projectId: _projectId);

  final String apiKey;
  final String projectId;
  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  Future<({String uid, String token})> _signIn(String googleIdToken) async {
    final response = await _client
        .post(
          Uri.https(
            'identitytoolkit.googleapis.com',
            '/v1/accounts:signInWithIdp',
            {'key': apiKey},
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'postBody': 'id_token=$googleIdToken&providerId=google.com',
            'requestUri': 'http://localhost',
            'returnSecureToken': true,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw StateError(
        'Free sync sign-in failed (${response.statusCode}: '
        '${_errorMessage(response.body)})',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (uid: body['localId'] as String, token: body['idToken'] as String);
  }

  /// Firebase's error reason (e.g. `INVALID_IDP_RESPONSE : ...`), which
  /// contains no secrets, so a failure on a device can be diagnosed.
  static String _errorMessage(String body) {
    try {
      final error = (jsonDecode(body) as Map<String, dynamic>)['error'];
      return (error as Map<String, dynamic>)['message'] as String? ?? body;
    } catch (_) {
      return body.length > 200 ? body.substring(0, 200) : body;
    }
  }

  Uri _documents([String path = '', Map<String, String>? query]) => Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$projectId/databases/(default)/documents/freeGoogleSyncs$path',
    query,
  );

  @override
  Future<bool> isUsed(String googleIdToken) async {
    final auth = await _signIn(googleIdToken);
    final response = await _client
        .get(
          _documents('/${auth.uid}'),
          headers: {'Authorization': 'Bearer ${auth.token}'},
        )
        .timeout(_timeout);
    if (response.statusCode == 200) return true;
    if (response.statusCode == 404) return false;
    throw StateError(
      'Free sync registry unavailable (${response.statusCode}: '
      '${_errorMessage(response.body)})',
    );
  }

  @override
  Future<void> record(String googleIdToken, DateTime month) async {
    final auth = await _signIn(googleIdToken);
    final response = await _client
        .post(
          _documents('', {'documentId': auth.uid}),
          headers: {
            'Authorization': 'Bearer ${auth.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'fields': {
              'month': {'stringValue': month.toIso8601String().substring(0, 7)},
              'createdAt': {
                'timestampValue': DateTime.now().toUtc().toIso8601String(),
              },
            },
          }),
        )
        .timeout(_timeout);
    // 409: already recorded (another phone or an earlier install).
    if (response.statusCode != 200 && response.statusCode != 409) {
      throw StateError('Free sync not recorded (${response.statusCode})');
    }
  }
}
