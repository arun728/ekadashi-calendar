import 'dart:convert';
import 'dart:io';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en =
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
  // Each language's own script; a language added to AppLanguage needs one.
  const scripts = {
    'ta': r'[\u0B80-\u0BFF]',
    'hi': r'[\u0900-\u097F]',
    'te': r'[\u0C00-\u0C7F]',
    'gu': r'[\u0A80-\u0AFF]',
    'bn': r'[\u0980-\u09FF]',
  };
  test('every app language has a script check', () {
    expect(
      AppLanguage.codes.where((c) => c != 'en').toSet(),
      scripts.keys.toSet(),
    );
  });
  for (final language in scripts.keys) {
    final script = RegExp(scripts[language]!);
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
    // Text, labels, hints and tooltips; Panchang follows the app language
    // too (docs/ROADMAP.md Phase 2).
    final expression = RegExp(
      r"(?:Text\(|labelText: |helperText: |hintText: |tooltip: |content: Text\()\s*'([^'\n]+)'",
    );
    const englishOnlyScreenFiles = <String>{};
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
