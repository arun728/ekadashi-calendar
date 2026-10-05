import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
  for (final language in ['ta', 'hi', 'te']) {
    final script = RegExp(
      language == 'ta'
          ? r'[\u0B80-\u0BFF]'
          : language == 'hi'
          ? r'[\u0900-\u097F]'
          : r'[\u0C00-\u0C7F]',
    );
    test(
      '$language has every UI key, native script and identical placeholders',
      () {
        final locale =
            jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
                as Map<String, dynamic>;
        final problems = <String>[];
        for (final key in en.keys.where((k) => !k.startsWith('@'))) {
          final value = locale[key];
          if (value is! String || value.trim().isEmpty) {
            problems.add('$key: missing');
            continue;
          }
          if (key != 'filter_google' && !script.hasMatch(value)) {
            problems.add('$key: untranslated');
          }
          final sourcePlaceholders =
              RegExp(
                  r'\{[^{}]+\}',
                ).allMatches(en[key] as String).map((e) => e.group(0)).toList()
                ..sort();
          final translatedPlaceholders = RegExp(
            r'\{[^{}]+\}',
          ).allMatches(value).map((e) => e.group(0)).toList()..sort();
          if (sourcePlaceholders.join('|') !=
              translatedPlaceholders.join('|')) {
            problems.add('$key: placeholder mismatch');
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      },
    );
  }
  test('screen Text literals do not bypass localization', () {
    final violations = <String>[];
    final expression = RegExp(r"Text\(\s*'([^'\n]+)'");
    // Panchang is intentionally English-only for this release, as approved in
    // AGENTS.md. Remove this exception when the feature is localized.
    const englishOnlyScreenFiles = {
      'lib/screens/panchang_screen.dart',
      'lib/screens/panchang_location_dialog.dart',
      'lib/screens/panchang_month_panels.dart',
      'lib/screens/more_screen.dart',
    };
    for (final file in [
      File('lib/main.dart'),
      ...Directory('lib/screens')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    ]) {
      if (englishOnlyScreenFiles.contains(file.path)) continue;
      for (final match in expression.allMatches(file.readAsStringSync())) {
        final value = match.group(1)!;
        if (RegExp('[A-Za-z]').hasMatch(value) && !value.contains(r'$')) {
          violations.add('${file.path}: $value');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
