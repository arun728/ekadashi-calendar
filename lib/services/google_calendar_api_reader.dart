import 'package:googleapis/calendar/v3.dart' as gcal;
import 'google_calendar_service.dart';

/// Pagination and recurrence expansion isolated from Android authentication.
class GoogleCalendarApiReader {
  final gcal.CalendarApi api;
  GoogleCalendarApiReader(this.api);
  Future<List<GoogleCalendarInfo>> listCalendars() async {
    final all = <GoogleCalendarInfo>[];
    String? token;
    do {
      final response = await api.calendarList.list(
        maxResults: 100,
        pageToken: token,
      );
      all.addAll(
        (response.items ?? [])
            .where((c) => c.id != null)
            .map(
              (c) => GoogleCalendarInfo(
                id: c.id!,
                summary: c.summary ?? c.id!,
                primary: c.primary == true,
                selected: c.selected != false,
              ),
            ),
      );
      token = response.nextPageToken;
    } while (token != null);
    return all;
  }

  Future<List<Map<String, dynamic>>> fetchEvents({
    required String accountId,
    required DateTime timeMin,
    required DateTime timeMax,
    required List<String> calendarIds,
  }) async {
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
            'id': e.id,
            'status': e.status,
            'accountId': accountId,
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
            map['start'] = {'dateTime': e.start!.dateTime!.toIso8601String()};
            map['end'] = {
              'dateTime': (e.end?.dateTime ?? e.start!.dateTime!)
                  .toIso8601String(),
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
