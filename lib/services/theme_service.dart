import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_icons.dart';

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  static const glassLookKey = 'android_glass_look_enabled';
  bool _glassLookEnabled = false;
  bool get isGlassLookEnabled => _glassLookEnabled;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? true;
    _glassLookEnabled = prefs.get(glassLookKey) == true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setGlassLook(bool enabled) async {
    _glassLookEnabled = enabled;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(
      glassLookKey,
      enabled,
    );
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    notifyListeners();
  }
}

/// The app themes. Material 3 needs an explicit colour scheme: without
/// one every unstyled control falls back to Material's purple. Teal
/// #00A19B is the iOS accent (Theme.teal); the top bar is the iOS inline
/// navigation bar: transparent, a 17 pt semibold title in the primary
/// colour, teal buttons and the iOS back chevron.
class AppTheme {
  static const teal = Color(0xFF00A19B);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primaryText = dark ? Colors.white : Colors.black;
    final typography = Typography.material2021(
      platform: TargetPlatform.android,
    );
    final scheme = ColorScheme.fromSeed(seedColor: teal, brightness: brightness)
        .copyWith(
          primary: teal,
          onPrimary: Colors.white,
          secondary: teal,
          onSecondary: Colors.white,
          tertiary: teal,
          surfaceTint: Colors.transparent,
        );
    return ThemeData(
      useMaterial3: true,
      typography: typography,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      cardColor: dark ? const Color(0xFF1F1F1F) : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: primaryText,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: teal),
        actionsIconTheme: const IconThemeData(color: teal),
        // From the typography, so the title keeps the app font.
        titleTextStyle: (dark ? typography.white : typography.black)
            .titleMedium!
            .copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(AppIcons.back, size: 22),
        closeButtonIconBuilder: (_) => const Icon(AppIcons.close),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: teal,
        selectionHandleColor: teal,
        selectionColor: teal.withValues(alpha: .3),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: teal),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        actionTextColor: teal,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: dark ? Colors.white70 : Colors.black87),
      ),
    );
  }

  static final lightTheme = _theme(Brightness.light);
  static final darkTheme = _theme(Brightness.dark);
}
