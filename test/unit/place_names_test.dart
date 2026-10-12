import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/l10n/place_names.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cities and countries show in the app language (assets/panchang/
/// place_names.json, shared with iOS).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PlaceNames.load);

  test('places and countries are named in each language', () {
    expect(PlaceNames.place('Chennai', 'hi'), 'चेन्नई');
    expect(PlaceNames.place('New Delhi', 'bn'), 'নয়াদিল্লি');
    expect(PlaceNames.place('Chennai', 'en'), 'Chennai');
    expect(PlaceNames.place('Nowhere', 'ta'), 'Nowhere');
    expect(PlaceNames.label('London (GB)', 'gu'), 'લંડન (યુનાઇટેડ કિંગડમ)');
    expect(PlaceNames.label('London (GB)', 'en'), 'London (GB)');
    expect(PlaceNames.country('IN', 'te'), 'భారతదేశం');
  });

  test('every Indian city in the Panchang list is named in each script', () {
    final rows =
        jsonDecode(File('assets/panchang/cities.json').readAsStringSync())
            as List<dynamic>;
    final latin = RegExp('[A-Za-z]');
    final missing = <String>[];
    for (final row in rows.cast<List<dynamic>>()) {
      if (row[3] != 'IN') continue;
      final label = '${row[1]} (IN)';
      for (final language in ['hi', 'ta', 'te', 'gu', 'bn']) {
        if (latin.hasMatch(PlaceNames.label(label, language))) {
          missing.add('$language: $label');
        }
      }
    }
    expect(missing.take(20), isEmpty, reason: '${missing.length} missing');
  });
}
