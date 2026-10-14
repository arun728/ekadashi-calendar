import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/l10n/place_names.dart';
import 'package:ekadashi_calendar/services/panchang/city_search_index.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The city search (Home and every Panchang sub-tab) must keep up with the
/// keyboard in every language. Names in the app language are prepared once
/// per language off the UI thread (CitySearchIndex), not for all 34,152
/// cities at every keystroke: a Tamil keystroke took about 2 s and froze the
/// keyboard (14 October 2026). Mirrors CitySearchIndexTests.swift.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const chennai = 'geonames-1264527';
  const mumbai = 'geonames-1275339';

  setUpAll(() async {
    // The real path: indexes are built in a background isolate.
    PanchangLocationStore.buildIndexInline = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          return ByteData.sublistView(File(key).readAsBytesSync());
        });
    PlaceNames.use(
      jsonDecode(File('assets/panchang/place_names.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    await PanchangLocationStore.cities();
  });

  test('the index is built once per language', () async {
    final tamil = await PanchangLocationStore.searchIndex('ta');
    expect(
      identical(tamil, await PanchangLocationStore.searchIndex('ta')),
      isTrue,
    );
    expect(tamil.language, 'ta');
  });

  test('every keystroke is fast once the index is built', () async {
    for (final language in ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
      final index = await PanchangLocationStore.searchIndex(language);
      for (final query in ['சென', 'ஸான்', 'zzq', 'मुं', 'che']) {
        final watch = Stopwatch()..start();
        index.search(query);
        // Was about 2,000 ms for Tamil.
        expect(
          watch.elapsedMilliseconds,
          lessThan(100),
          reason: '$language $query',
        );
      }
    }
  });

  test('cities are found by their name in the app language', () async {
    final tamil = await PanchangLocationStore.searchIndex('ta');
    expect(tamil.search('சென').map((c) => c.id), contains(chennai));
    expect(tamil.search('chenn').map((c) => c.id), contains(chennai));
    final hindi = await PanchangLocationStore.searchIndex('hi');
    expect(hindi.search('मुं').map((c) => c.id), contains(mumbai));
  });

  test('short queries search nothing', () async {
    expect(CitySearchIndex.query(' c '), isNull);
    expect(CitySearchIndex.query(' Che '), 'che');
    expect(CitySearchIndex.query('मुं'), 'मुं');
    expect(
      (await PanchangLocationStore.searchIndex('en')).search('c'),
      isEmpty,
    );
  });
}
