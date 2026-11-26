import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Settings redesign strings (test/fixtures/settings_copy.json, also read by
/// the Swift SettingsCopyTests): the same text on both apps.
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/settings_copy.json').readAsStringSync())
          as Map<String, dynamic>;
  test('Android shows the Settings redesign strings in every language', () {
    for (final language in ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
      final arb =
          jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
              as Map<String, dynamic>;
      (fixture[language] as Map<String, dynamic>).forEach((key, value) {
        expect(arb[key], value, reason: '$language $key');
      });
    }
  });
}
