import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['en', 'ta', 'hi']) {
    test(
      'Saved $locale language is restored before listeners use translated UI',
      () async {
        SharedPreferences.setMockInitialValues({'language_code': locale});
        final service = LanguageService();
        final ready = Completer<void>();
        service.addListener(() => ready.complete());
        await ready.future;
        expect(service.currentLocale.languageCode, locale);
        expect(
          service.localizedStrings['app_title'],
          service.translate('app_title'),
        );
        service.dispose();
      },
    );
  }
  test(
    'Language change persists and a new service restores the selection',
    () async {
      final first = LanguageService();
      await first.changeLanguage('ta');
      expect(
        (await SharedPreferences.getInstance()).getString('language_code'),
        'ta',
      );
      final restored = LanguageService();
      final ready = Completer<void>();
      restored.addListener(() => ready.complete());
      await ready.future;
      expect(restored.translate('home'), first.translate('home'));
      expect(restored.translate('missing-review-key'), 'missing-review-key');
      first.dispose();
      restored.dispose();
    },
  );
  test(
    'Unsupported locale falls back to English and substitutions are localized',
    () async {
      final service = LanguageService();
      await service.changeLanguage('xx');
      expect(service.translate('home'), 'Home');
      expect(service.translateWithArgs('in_days', ['12']), 'in 12 days');
      await service.changeLanguage('hi');
      expect(
        service.translateWithArgs('reminders_active', ['2']),
        contains('2'),
      );
      expect(
        service.translateWithArgs('reminders_active', ['2']),
        isNot(contains('{}')),
      );
      service.dispose();
    },
  );
  test(
    'Theme defaults to dark and saved appearance survives service recreation',
    () async {
      final first = ThemeService();
      await first.loadTheme();
      expect(first.themeMode, ThemeMode.dark);
      await first.toggleTheme(false);
      expect(first.isDarkMode, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool('is_dark_mode'),
        isFalse,
      );
      final restored = ThemeService();
      await restored.loadTheme();
      expect(restored.themeMode, ThemeMode.light);
      await restored.toggleTheme(true);
      expect(restored.isDarkMode, isTrue);
      first.dispose();
      restored.dispose();
    },
  );
}
