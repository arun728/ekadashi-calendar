import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['en', 'ta', 'hi', 'te', 'gu', 'bn']) {
    testWidgets('$locale Home localizes fasting and fast-breaking dates', (
      tester,
    ) async {
      final harness = AppHarness();
      await tester.runAsync(
        () => harness.install(preferences: {'language_code': locale}),
      );
      addTearDown(harness.uninstall);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .whereType<String>()
          .toList();
      final breakDates = EkadashiService()
          .getEkadashis(timezone: 'IST', languageCode: locale)
          .map(
            (e) => DateFormat(
              'MMM dd, yyyy',
              locale,
            ).format(e.date.add(const Duration(days: 1))),
          )
          .toSet();
      expect(
        text.any(breakDates.contains),
        isTrue,
        reason: 'Home must render a localized fast-breaking date in $locale',
      );
      if (locale != 'en') {
        final englishDate = RegExp(
          r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{2}, \d{4}$',
        );
        expect(
          text.where(englishDate.hasMatch),
          isEmpty,
          reason: 'Home dates must not silently fall back to English',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
