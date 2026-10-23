import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'missing or invalid tradition defaults Vaishnava; explicit choices survive',
    () async {
      for (final saved in [null, 'invalid', 'smarta', 'gaudiya']) {
        SharedPreferences.setMockInitialValues({
          if (saved != null) EkadashiSettings.traditionKey: saved,
        });
        final settings = EkadashiSettings();
        await settings.load();
        expect(
          settings.tradition,
          saved == 'smarta'
              ? EkadashiTradition.smarta
              : EkadashiTradition.gaudiya,
        );
      }
    },
  );
  for (final language in AppLanguage.all) {
    test('both endpoints of AM/PM windows translated in ${language.code}', () {
      for (final window in [
        '06:00 AM - 08:21 AM',
        '11:30 AM - 01:00 PM',
        '01:00 PM - 02:00 PM',
      ]) {
        final text = AppStrings.localizeClock(window, language.code);
        final expected = window
            .replaceAll(
              'AM',
              AppStrings.translate('panchang_am', language.code),
            )
            .replaceAll(
              'PM',
              AppStrings.translate('panchang_pm', language.code),
            );
        expect(text, expected);
        if (language.code != 'en') {
          expect(RegExp('[A-Za-z]').hasMatch(text), isFalse);
        }
      }
    });
  }
}
