import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ekadashi_calendar/services/google_calendar_api_reader.dart';

void main() {
  test(
    'Calendar list and recurring event instances follow every page with read-only requests',
    () async {
      final calls = <Uri>[];
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        calls.add(request.url);
        final next = request.url.queryParameters['pageToken'];
        if (request.url.path.endsWith('calendarList')) {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': next == null ? 'primary' : 'holidays'},
              ],
              if (next == null) 'nextPageToken': 'calendar-page-2',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.url.queryParameters['singleEvents'], 'true');
        expect(
          DateTime.parse(request.url.queryParameters['timeMin']!),
          DateTime.utc(2027),
        );
        expect(
          DateTime.parse(request.url.queryParameters['timeMax']!),
          DateTime.utc(2028),
        );
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': next == null ? 'instance-1' : 'instance-2',
                'start': {'date': '2027-12-31'},
                'end': {'date': '2028-01-01'},
              },
            ],
            if (next == null) 'nextPageToken': 'events-page-2',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final reader = GoogleCalendarApiReader(CalendarApi(client));
      expect((await reader.listCalendars()).map((c) => c.id), [
        'primary',
        'holidays',
      ]);
      final events = await reader.fetchEvents(
        accountId: 'account',
        calendarIds: ['primary', 'holidays'],
        timeMin: DateTime.utc(2027),
        timeMax: DateTime.utc(2028),
      );
      expect(events, hasLength(4));
      expect(events.map((e) => e['calendarId']).toSet(), {
        'primary',
        'holidays',
      });
      expect(calls, hasLength(6));
      client.close();
    },
  );
  test(
    'A failed later page aborts the import instead of publishing a partial year',
    () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['pageToken'] != null) {
          return http.Response(
            '{"error":{"code":503,"message":"Unavailable"}}',
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"items":[],"nextPageToken":"second"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final reader = GoogleCalendarApiReader(CalendarApi(client));
      await expectLater(
        reader.fetchEvents(
          accountId: 'account',
          calendarIds: ['primary'],
          timeMin: DateTime.utc(2027),
          timeMax: DateTime.utc(2028),
        ),
        throwsA(isA<Exception>()),
      );
      client.close();
    },
  );
}
