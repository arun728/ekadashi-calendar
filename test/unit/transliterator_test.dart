import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/l10n/transliterator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every city in the world shows in the app language: names the place-name
/// table lacks are written in the language's script by sound, exactly as on
/// iOS (TransliteratorTests.swift writes the shared fixture).
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/transliteration.json').readAsStringSync())
          as Map<String, dynamic>;
  final rows =
      jsonDecode(File('assets/panchang/cities.json').readAsStringSync())
          as List;
  const languages = ['hi', 'ta', 'te', 'gu', 'bn'];

  test('writes names by sound', () {
    expect(transliterate('Toronto', 'hi'), 'टोरोंटो');
    expect(transliterate('Boston', 'hi'), 'बोस्टन');
    expect(transliterate('Philadelphia', 'hi'), 'फ़िलडेल्फ़िया');
    expect(transliterate('Ḩattā', 'hi'), 'हटा');
    expect(transliterate('Washington', 'ta'), 'வஷிங்க்டன்');
    expect(transliterate('York', 'bn'), 'ইয়োর্ক');
    expect(transliterate('Toronto', 'en'), 'Toronto');
  });

  test('matches the iOS fixture name by name', () {
    for (final entry in fixture.entries) {
      if (entry.key.startsWith('_')) continue;
      for (final language in languages) {
        expect(
          transliterate(entry.key, language),
          (entry.value as Map)[language],
          reason: '$language ${entry.key}',
        );
      }
    }
  });

  test('writes the whole catalog exactly as iOS, with no Latin letters', () {
    final hashes = fixture['_catalog_fnv1a32'] as Map<String, dynamic>;
    final latin = RegExp('[A-Za-z]');
    for (final language in languages) {
      var hash = 2166136261;
      for (final row in rows) {
        final text = transliterate(row[1] as String, language);
        expect(latin.hasMatch(text), isFalse, reason: '$language ${row[1]}');
        expect(text, isNotEmpty, reason: '$language ${row[1]}');
        for (final byte in utf8.encode('$text\n')) {
          hash = ((hash ^ byte) * 16777619) & 0xffffffff;
        }
      }
      expect(hash.toRadixString(16), hashes[language], reason: language);
    }
  });
}
