import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'transliterator.dart';

/// City and country names in the app language (assets/panchang/
/// place_names.json, shared with iOS). Names not in the table are written in
/// the language's script by sound ([transliterate]), so a city never shows
/// in Latin letters outside English.
class PlaceNames {
  const PlaceNames._();

  static Map<String, Map<String, String>> _places = const {};
  static Map<String, Map<String, String>> _countries = const {};
  static Future<void>? _loading;

  /// Reads the table once; later calls share the same load.
  static Future<void> load() => _loading ??= _read();

  static Future<void> _read() async {
    try {
      // Decoded here rather than with loadString, which hands large files
      // to an isolate.
      final bytes = await rootBundle.load('assets/panchang/place_names.json');
      use(
        jsonDecode(utf8.decode(bytes.buffer.asUint8List()))
            as Map<String, dynamic>,
      );
    } catch (_) {
      _loading = null;
    }
  }

  /// Installs a decoded table (tests and the loader).
  static void use(Map<String, dynamic> data) {
    Map<String, Map<String, String>> table(String key) => {
      for (final entry in (data[key] as Map<String, dynamic>).entries)
        entry.key: Map<String, String>.from(entry.value as Map),
    };
    _places = table('places');
    _countries = table('countries');
  }

  /// [name] in [language]: the table's translation, else [name] written in
  /// the language's script by sound.
  static String place(String name, String language) {
    if (language == 'en' || name.isEmpty) return name;
    return _translation(name, language) ?? transliterate(name, language);
  }

  /// Whether the table has [name] in [language] (else it is transliterated).
  static bool isKnown(String name, String language) =>
      language == 'en' || _translation(name, language) != null;

  static String? _translation(String name, String language) =>
      _places[name]?[language] ?? _places[name.trim()]?[language];

  /// The country with ISO code [code] in [language]; the code in English.
  static String country(String code, String language) =>
      language == 'en' ? code : _countries[code]?[language] ?? code;

  static final _labelWithCountry = RegExp(r'^(.*) \(([A-Z]{2})\)$');

  /// A Panchang city label: "Chennai" or "Chennai (IN)" from the worldwide
  /// list, with the country spelled out in other languages.
  static String label(String label, String language) {
    if (language == 'en') return label;
    final match = _labelWithCountry.firstMatch(label);
    if (match == null) return place(label, language);
    return '${place(match[1]!, language)} (${country(match[2]!, language)})';
  }
}
