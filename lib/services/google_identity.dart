import 'package:google_sign_in/google_sign_in.dart';

/// One shared native sign-in session; calendar permission requested separately.
class AppGoogleIdentity {
  static const serverClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static final GoogleSignIn signIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: serverClientId.isEmpty ? null : serverClientId,
  );
}
