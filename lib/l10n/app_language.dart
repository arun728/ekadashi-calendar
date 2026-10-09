import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'localized_lookup.dart';
import 'place_names.dart';

/// The languages the app speaks, in menu order (the Swift `AppLanguage`).
/// New languages are appended at the end, never
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
    AppLanguage('gu', 'ગુજરાતી'),
    AppLanguage('bn', 'বাংলা'),
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

  /// A clock time such as "6:24 PM", with [language]'s own words for AM and
  /// PM (the date library writes them in Latin letters for most languages).
  static String clock(int hour, int minute, String language) {
    final shown = hour % 12 == 0 ? 12 : hour % 12;
    final marker = translate(
      hour < 12 ? 'panchang_am' : 'panchang_pm',
      language,
    );
    return '$shown:${minute.toString().padLeft(2, '0')} $marker';
  }

  static final _meridiem = RegExp(r'\b(AM|PM)\b');

  /// Stored times such as "06:00 AM - 08:21 AM" with [language]'s AM and PM.
  static String localizeClock(String text, String language) =>
      text.replaceAllMapped(
        _meridiem,
        (m) =>
            translate(m[1] == 'AM' ? 'panchang_am' : 'panchang_pm', language),
      );

  /// A city or country name in [language] (PlaceNames).
  static String placeName(String name, String language) =>
      PlaceNames.place(name, language);

  /// "UTC+5:30" for a UTC offset in minutes, in [language]'s script.
  static String utcOffset(int minutes, String language) {
    final sign = minutes < 0 ? '−' : '+';
    final total = minutes.abs();
    final hours = total ~/ 60, rest = total % 60;
    final value = rest == 0
        ? '$sign$hours'
        : '$sign$hours:${rest.toString().padLeft(2, '0')}';
    return translateWithArgs('utc_offset', language, [value]);
  }

  /// The app time zone (IST, EST, ...) as [language] names it.
  static String timeZoneName(String code, String language) {
    final key = 'timezone_$code';
    final text = translate(key, language);
    return text == key ? code : text;
  }

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
