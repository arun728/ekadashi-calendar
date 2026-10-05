import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

/// Google sign-in is used only for read-only Google Calendar import. Premium
/// access comes from Google Play and never requires this sign-in.
class AppGoogleIdentity {
  static final GoogleSignIn signIn = GoogleSignIn(
    scopes: const [gcal.CalendarApi.calendarReadonlyScope],
  );
}
