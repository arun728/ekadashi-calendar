import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Glass starts Off for missing/invalid preferences and persists independently of Dark Mode',
    () async {
      for (final seed in <Map<String, Object>>[
        {},
        {'android_glass_look_enabled': 'invalid'},
      ]) {
        SharedPreferences.setMockInitialValues(seed);
        final theme = ThemeService();
        await theme.loadTheme();
        expect(theme.isGlassLookEnabled, isFalse);
        await theme.setGlassLook(true);
        await theme.toggleTheme(false);
        final restarted = ThemeService();
        await restarted.loadTheme();
        expect(restarted.isGlassLookEnabled, isTrue);
        expect(restarted.isDarkMode, isFalse);
        await restarted.setGlassLook(false);
        final again = ThemeService();
        await again.loadTheme();
        expect(again.isGlassLookEnabled, isFalse);
        expect(again.isDarkMode, isFalse);
      }
    },
  );
}
