import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ekadashi_calendar/services/free_sync_registry.dart';

void main() {
  const doc =
      'https://firestore.googleapis.com/v1/projects/ekadashi-test/databases/(default)/documents/freeGoogleSyncs';

  FirestoreFreeSyncRegistry registry(
    List<http.Request> calls,
    http.Response Function(http.Request request) firestore,
  ) => FirestoreFreeSyncRegistry(
    apiKey: 'web-api-key',
    projectId: 'ekadashi-test',
    client: MockClient((request) async {
      calls.add(request);
      if (request.url.host == 'identitytoolkit.googleapis.com') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['postBody'], 'id_token=google-token&providerId=google.com');
        return http.Response(
          jsonEncode({'idToken': 'firebase-token', 'localId': 'uid-1'}),
          200,
        );
      }
      expect(request.headers['Authorization'], 'Bearer firebase-token');
      return firestore(request);
    }),
  );

  test(
    'signs in with the Google ID token and reads the account record',
    () async {
      final calls = <http.Request>[];
      final unused = registry(calls, (_) => http.Response('{}', 404));
      expect(await unused.isUsed('google-token'), isFalse);
      expect(calls.first.url.queryParameters['key'], 'web-api-key');
      expect(calls.last.method, 'GET');
      expect(calls.last.url.toString(), '$doc/uid-1');
      final used = registry(calls, (_) => http.Response('{"name":"x"}', 200));
      expect(await used.isUsed('google-token'), isTrue);
    },
  );

  test('records the month once per account', () async {
    final calls = <http.Request>[];
    final fresh = registry(calls, (_) => http.Response('{}', 200));
    await fresh.record('google-token', DateTime(2026, 10, 1));
    final create = calls.last;
    expect(create.method, 'POST');
    expect(create.url.queryParameters['documentId'], 'uid-1');
    final fields = (jsonDecode(create.body) as Map)['fields'] as Map;
    expect(fields['month'], {'stringValue': '2026-10'});
    // Already recorded (e.g. a second device): still fine.
    final existing = registry(calls, (_) => http.Response('{}', 409));
    await existing.record('google-token', DateTime(2026, 10, 1));
  });

  test(
    'an unreachable registry throws so the free sync is not handed out',
    () async {
      final failing = registry([], (_) => http.Response('oops', 503));
      await expectLater(failing.isUsed('google-token'), throwsStateError);
    },
  );

  test('is only enabled when Firebase settings are built in', () {
    expect(FirestoreFreeSyncRegistry.fromEnvironment(), isNull);
  });
}
