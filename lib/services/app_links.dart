/// Store links for sharing (AppLinks.swift). Each platform shares only its
/// own store: Android the Play Store link (AGENTS.md "Store links").
class AppLinks {
  AppLinks._();

  /// The live v1 Android app.
  static const playStore =
      'https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar';

  /// The text shared with a share card on Android: the translated message,
  /// then the Play Store link only.
  static String shareCardMessage(String message) => '$message\n\n$playStore';
}
