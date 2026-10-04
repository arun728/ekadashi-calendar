import 'google_identity.dart';
import 'google_calendar_api_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

import 'google_calendar_service.dart';

class GoogleAuthGatewayAndroid implements GoogleAuthGateway {
  GoogleAuthGatewayAndroid({GoogleSignIn? signIn})
    : _signIn =
          signIn ??
          AppGoogleIdentity.signIn;

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

  @override
  Future<bool> signIn() async {
    try {
      final account = await _signIn.signIn();
      if (account == null) return false;
      if (!await _signIn.requestScopes([gcal.CalendarApi.calendarReadonlyScope])) return false;
      await _ensureApi();
      return true;
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      return false;
    }
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
    if (!await _signIn.requestScopes([gcal.CalendarApi.calendarReadonlyScope])) {
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
