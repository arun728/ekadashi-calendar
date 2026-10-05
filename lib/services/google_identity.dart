import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

/// Google sign-in is used only for read-only Google Calendar import. Premium
/// access comes from Google Play and never requires this sign-in.
class AppGoogleIdentity {
  static const scopes = [gcal.CalendarApi.calendarReadonlyScope];

  /// Firebase's web OAuth client, set at build time with the free-sync
  /// registry, so sign-in also returns an ID token for that registry.
  static const serverClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static final GoogleSignIn signIn = GoogleSignIn(
    scopes: scopes,
    serverClientId: serverClientId.isEmpty ? null : serverClientId,
  );
}
