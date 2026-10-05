import 'google_identity.dart';
import 'google_calendar_api_reader.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

import 'google_calendar_service.dart';

class GoogleAuthGatewayAndroid implements GoogleAuthGateway {
  GoogleAuthGatewayAndroid({GoogleSignIn? signIn})
    : _signIn = signIn ?? AppGoogleIdentity.signIn;

  final GoogleSignIn _signIn;
  gcal.CalendarApi? _api;
  drive.DriveApi? _drive;
  static const _freeSyncFile = 'ekadashi_free_google_sync.json';
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
    _drive = null;
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
    _drive = drive.DriveApi(client);
    _apiAccount = account;
  }

  Future<List<drive.File>> _freeSyncMarkers() async {
    final result = await _drive!.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_freeSyncFile'",
      $fields: 'files(id)',
    );
    return result.files ?? const [];
  }

  @override
  Future<bool> freeSyncUsed() async {
    await _ensureApi();
    return (await _freeSyncMarkers()).isNotEmpty;
  }

  @override
  Future<void> markFreeSyncUsed(DateTime month) async {
    await _ensureApi();
    if ((await _freeSyncMarkers()).isNotEmpty) return;
    final bytes = utf8.encode(
      jsonEncode({'month': month.toIso8601String().substring(0, 7)}),
    );
    await _drive!.files.create(
      drive.File()
        ..name = _freeSyncFile
        ..parents = ['appDataFolder'],
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
    );
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
