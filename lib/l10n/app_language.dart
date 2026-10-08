import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'localized_lookup.dart';

/// The languages the app speaks, in menu order (the Swift `AppLanguage`).
/// New languages (Bengali, Gujarati, ...) are appended at the end, never
/// inserted earlier, and need their strings in every ARB file (the tests
/// check).
class AppLanguage {
  const AppLanguage(this.code, this.nativeName);
  final String code;

  /// The language's own name, as the language menu shows it.
  final String nativeName;

  static const all = [
    AppLanguage('en', 'English'),
    AppLanguage('hi', 'हिंदी'),
    AppLanguage('ta', 'தமிழ்'),
    AppLanguage('te', 'తెలుగు'),
  ];

  static List<String> get codes => [for (final l in all) l.code];

  static AppLanguage named(String code) =>
      all.firstWhere((l) => l.code == code, orElse: () => all.first);
}

/// UI strings by key in any app language, outside the widget tree (search
/// titles, reminders, Panchang terms).
class AppStrings {
  const AppStrings._();
  static final _tables = <String, Map<String, String>>{};

  static Map<String, String> table(String language) =>
      _tables[language] ??= localizedTemplates(
        lookupAppLocalizations(
          Locale(AppLanguage.codes.contains(language) ? language : 'en'),
        ),
      );

  /// The string for [key] in [language]; English, then the key, when missing.
  static String translate(String key, String language) =>
      table(language)[key] ?? table('en')[key] ?? key;

  /// Fills `{value0}`, `{value1}`, ... by position in [args], wherever the
  /// translation puts them.
  static String translateWithArgs(
    String key,
    String language,
    List<String> args,
  ) {
    var text = translate(key, language);
    for (final (index, arg) in args.indexed) {
      text = text.replaceAll('{value$index}', arg);
    }
    return text;
  }
}
