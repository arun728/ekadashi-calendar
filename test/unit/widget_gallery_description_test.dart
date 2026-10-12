import 'dart:io';

import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Android widget gallery describes each widget with the iOS texts
/// (widget_desc_ekadashi / widget_desc_upcoming) in every app language.
void main() {
  const res = 'android/app/src/main/res';
  const providers = {
    'ekadashi_widget_info.xml': 'widget_desc_ekadashi',
    'widget_ekadashi_today_info.xml': 'widget_desc_ekadashi',
    'widget_upcoming_ekadashis_info.xml': 'widget_desc_upcoming',
  };

  String unescape(String value) => value
      .replaceAll(r"\'", "'")
      .replaceAll(r'\"', '"')
      .replaceAll('&amp;', '&');

  Map<String, String> strings(String folder) {
    final xml = File('$res/$folder/strings.xml').readAsStringSync();
    return {
      for (final m in RegExp(
        r'<string name="([^"]+)">([^<]*)</string>',
      ).allMatches(xml))
        m[1]!: unescape(m[2]!),
    };
  }

  for (final entry in providers.entries) {
    test('${entry.key} has a gallery description in every language', () {
      final xml = File('$res/xml/${entry.key}').readAsStringSync();
      final match = RegExp(
        r'android:description="@string/([a-z_]+)"',
      ).firstMatch(xml);
      expect(match, isNotNull, reason: 'android:description is missing');
      final name = match![1]!;
      for (final (folder, language) in [
        ('values', 'en'),
        ('values-hi', 'hi'),
        ('values-ta', 'ta'),
        ('values-te', 'te'),
        ('values-gu', 'gu'),
        ('values-bn', 'bn'),
      ]) {
        expect(
          strings(folder)[name],
          AppStrings.translate(entry.value, language),
          reason: '$folder/$name',
        );
      }
    });
  }
}
