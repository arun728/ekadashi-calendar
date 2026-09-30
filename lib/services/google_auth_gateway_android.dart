import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

import 'google_calendar_service.dart';

class GoogleAuthGatewayAndroid implements GoogleAuthGateway {
  GoogleAuthGatewayAndroid({GoogleSignIn? signIn})
      : _signIn = signIn ??
            GoogleSignIn(
              scopes: const [
                gcal.CalendarApi.calendarReadonlyScope,
              ],
            );

  final GoogleSignIn _signIn;
  gcal.CalendarApi? _api;

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
      await _ensureApi();
      return true;
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    _api = null;
    await _signIn.signOut();
  }

  Future<void> _ensureApi() async {
    if (_api != null) return;
    final client = await _signIn.authenticatedClient();
    if (client == null) {
      throw StateError('No authenticated Google client');
    }
    _api = gcal.CalendarApi(client as http.Client);
  }

  @override
  Future<List<GoogleCalendarInfo>> listCalendars() async {
    await _ensureApi();
    final response = await _api!.calendarList.list(maxResults: 100);
    final items = response.items ?? [];
    return items
        .where((c) => c.id != null)
        .map((c) => GoogleCalendarInfo(
              id: c.id!,
              summary: c.summary ?? c.id!,
              primary: c.primary == true,
              selected: c.selected != false,
            ))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    required List<String> calendarIds,
  }) async {
    await _ensureApi();
    final api = _api!;
    final all = <Map<String, dynamic>>[];

    for (final calendarId in calendarIds) {
      String? pageToken;
      do {
        final response = await api.events.list(
          calendarId,
          timeMin: timeMin.toUtc(),
          timeMax: timeMax.toUtc(),
          singleEvents: true,
          orderBy: 'startTime',
          maxResults: 250,
          pageToken: pageToken,
        );
        for (final e in response.items ?? []) {
          final map = <String, dynamic>{
            'id': e.id == null ? null : '${calendarId}::${e.id}',
            'summary': e.summary,
            'description': e.description,
            'calendarId': calendarId,
          };
          if (e.start?.date != null) {
            map['start'] = {
              'date': e.start!.date!.toIso8601String().substring(0, 10),
            };
            map['end'] = {
              'date': (e.end?.date ?? e.start!.date!)
                  .toIso8601String()
                  .substring(0, 10),
            };
          } else if (e.start?.dateTime != null) {
            map['start'] = {
              'dateTime': e.start!.dateTime!.toIso8601String(),
            };
            map['end'] = {
              'dateTime':
                  (e.end?.dateTime ?? e.start!.dateTime!).toIso8601String(),
            };
          }
          all.add(map);
        }
        pageToken = response.nextPageToken;
      } while (pageToken != null);
    }
    return all;
  }
}
