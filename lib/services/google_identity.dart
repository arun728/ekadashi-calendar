import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis/drive/v3.dart' as drive;

/// Google sign-in is used only for read-only Google Calendar import. Premium
/// access comes from Google Play and never requires this sign-in.
class AppGoogleIdentity {
  /// Read-only Calendar, plus the app's own hidden Drive folder
  /// (non-sensitive) that remembers the account's one free sync.
  static const scopes = [
    gcal.CalendarApi.calendarReadonlyScope,
    drive.DriveApi.driveAppdataScope,
  ];
  static final GoogleSignIn signIn = GoogleSignIn(scopes: scopes);
}
