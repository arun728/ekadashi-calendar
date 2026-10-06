import 'google_identity.dart';
import 'google_calendar_api_reader.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

import 'google_calendar_service.dart';

class GoogleAuthGatewayAndroid implements GoogleAuthGateway {
  GoogleAuthGatewayAndroid({GoogleSignIn? signIn})
    : _signIn = signIn ?? AppGoogleIdentity.signIn;

  final GoogleSignIn _signIn;
  gcal.CalendarApi? _api;
  http.Client? _client;
  String? _apiAccount;

  @override
  Future<String?> accountId() async =>
      (_signIn.currentUser ?? await _signIn.signInSilently())?.id;

  @override
  Future<bool> isSignedIn() async {
    final account = _signIn.currentUser ?? await _signIn.signInSilently();
    return account != null;
  }

  /// Returns false when the user cancels. Configuration, network or Play
  /// services failures are rethrown so the UI can say sign-in failed.
  @override
  Future<bool> signIn() async {
    final account = await _signIn.signIn();
    if (account == null) return false;
    if (!await _signIn.requestScopes(AppGoogleIdentity.scopes)) {
      return false;
    }
    await _ensureApi();
    return true;
  }

  @override
  Future<void> signOut() async {
    _client?.close();
    _client = null;
    _api = null;
    _apiAccount = null;
    await _signIn.signOut();
  }

  Future<void> _ensureApi() async {
    final account = await accountId();
    if (_api != null && _apiAccount == account) return;
    if (!await _signIn.requestScopes(AppGoogleIdentity.scopes)) {
      throw StateError('Calendar permission required');
    }
    _client?.close();
    final client = await _signIn.authenticatedClient();
    if (client == null) {
      throw StateError('No authenticated Google client');
    }
    _client = client;
    _api = gcal.CalendarApi(client);
    _apiAccount = account;
  }

  /// A fresh ID token: Google ID tokens expire after an hour and the cached
  /// account can hold an expired one, which Firebase rejects.
  @override
  Future<String?> idToken() async {
    final account =
        await _signIn.signInSilently(reAuthenticate: true) ??
        _signIn.currentUser;
    return (await account?.authentication)?.idToken;
  }

  @override
  Future<String?> accountEmail() async =>
      (_signIn.currentUser ?? await _signIn.signInSilently())?.email;

  @override
  Future<List<GoogleCalendarInfo>> listCalendars() async {
    await _ensureApi();
    return GoogleCalendarApiReader(_api!).listCalendars();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    required List<String> calendarIds,
  }) async {
    await _ensureApi();
    return GoogleCalendarApiReader(_api!).fetchEvents(
      accountId: _apiAccount!,
      timeMin: timeMin,
      timeMax: timeMax,
      calendarIds: calendarIds,
    );
  }
}
