import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The billing and Journey copy Arun approved on 25 Nov 2026
/// (test/fixtures/billing_copy.json, also read by the Swift
/// BillingCopyTests): shared keys match iOS exactly and store keys differ
/// only in the store name. No billing string shows a date.
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/billing_copy.json').readAsStringSync())
          as Map<String, dynamic>;
  Map<String, dynamic> arb(String language) =>
      jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('Android shows the approved copy in every language', () {
    for (final language in ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
      final rows = fixture[language] as Map<String, dynamic>;
      final strings = arb(language);
      rows.forEach((key, value) {
        final row = value as Map<String, dynamic>;
        expect(
          strings[key],
          row['both'] ?? row['android'],
          reason: '$language $key',
        );
      });
    }
  });

  test('dated billing strings are gone', () {
    final removed = (fixture['removed_keys'] as List).cast<String>();
    for (final language in ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
      final strings = arb(language);
      for (final key in removed) {
        expect(strings.containsKey(key), isFalse, reason: '$language $key');
      }
    }
  });
}
