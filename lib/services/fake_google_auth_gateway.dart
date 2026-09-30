import 'google_calendar_service.dart';

class FakeGoogleAuthGateway implements GoogleAuthGateway {
  FakeGoogleAuthGateway({
    this.signedIn = false,
    this.events = const [],
    this.calendars = const [
      GoogleCalendarInfo(id: 'primary', summary: 'Primary', primary: true),
    ],
    this.failSignIn = false,
  });

  bool signedIn;
  bool failSignIn;
  List<Map<String, dynamic>> events;
  List<GoogleCalendarInfo> calendars;

  @override
  Future<bool> isSignedIn() async => signedIn;

  @override
  Future<bool> signIn() async {
    if (failSignIn) return false;
    signedIn = true;
    return true;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
  }

  @override
  Future<List<GoogleCalendarInfo>> listCalendars() async => calendars;

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    required List<String> calendarIds,
  }) async {
    return events
        .where((e) =>
            calendarIds.isEmpty ||
            calendarIds.contains(e['calendarId'] ?? 'primary'))
        .toList();
  }
}
