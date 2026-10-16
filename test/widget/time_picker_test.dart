import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/widgets/time_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every time picker is the iPhone's wheel (DatePicker hourAndMinute on
/// iOS), not Material's clock dial: 12-hour in English, 24-hour in the
/// other languages (no Latin AM and PM), with Cancel and Done.
void main() {
  TimeOfDay? result;

  Future<void> open(WidgetTester tester, String code) async {
    SharedPreferences.setMockInitialValues({'language_code': code});
    final language = LanguageService();
    await language.changeLanguage(code);
    result = null;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await pickTime(
                context,
                const TimeOfDay(hour: 7, minute: 30),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a wheel, 12-hour in English; Done keeps the time', (
    tester,
  ) async {
    await open(tester, 'en');
    expect(find.byType(TimePickerDialog), findsNothing);
    final wheel = tester.widget<CupertinoDatePicker>(
      find.byKey(const Key('time_picker_wheel')),
    );
    expect(wheel.mode, CupertinoDatePickerMode.time);
    expect(wheel.use24hFormat, isFalse);
    expect(wheel.initialDateTime.hour, 7);
    expect(wheel.initialDateTime.minute, 30);
    await tester.tap(find.byKey(const Key('time_picker_done')));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 7, minute: 30));
  });

  testWidgets('a turned wheel gives the new time; Cancel gives none', (
    tester,
  ) async {
    await open(tester, 'en');
    tester
        .widget<CupertinoDatePicker>(find.byKey(const Key('time_picker_wheel')))
        .onDateTimeChanged(DateTime(2026, 1, 1, 18, 45));
    await tester.tap(find.byKey(const Key('time_picker_done')));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 18, minute: 45));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('time_picker_cancel')));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  for (final code in ['hi', 'ta', 'te', 'gu', 'bn']) {
    testWidgets('24-hour wheel in $code', (tester) async {
      await open(tester, code);
      final wheel = tester.widget<CupertinoDatePicker>(
        find.byKey(const Key('time_picker_wheel')),
      );
      expect(wheel.use24hFormat, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
