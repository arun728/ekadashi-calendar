// Writes the curated search catalog for the native iOS app:
//   flutter test test/tool/dump_search_catalog_test.dart
// Output: ios-native/EkadashiCore/Sources/EkadashiCore/Resources/search/catalog.json
// The Dart catalog stays the source of truth; ResourceSyncTests on iOS checks
// the copy is current.
import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/content_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dump curated search catalog for iOS', () async {
    SharedPreferences.setMockInitialValues({});
    final entries = await ContentCatalogService().buildAllCatalogEntries(
      ekadashiList: const [],
      currentLanguage: 'en',
    );
    final rows = [
      for (final entry in entries)
        {...entry.toJson(), 'updatedAtUTC': null, 'isDownloaded': null},
    ];
    final file = File(
      'ios-native/EkadashiCore/Sources/EkadashiCore/Resources/search/catalog.json',
    )..createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent(' ').convert(rows)}\n',
    );
    expect(rows, isNotEmpty);
  });
}
