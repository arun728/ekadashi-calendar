// Checks the curated search catalog copied into the native iOS app is
// current; regenerate it with:
//   UPDATE_IOS_FIXTURES=1 flutter test test/tool/dump_search_catalog_test.dart
// Output: ios-native/EkadashiCore/Sources/EkadashiCore/Resources/search/catalog.json
// The Dart catalog stays the source of truth.
import 'dart:convert';
import 'dart:io';

import 'package:ekadashi_calendar/services/content_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('iOS search catalog matches the Dart catalog', () async {
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
    );
    final expected = '${const JsonEncoder.withIndent(' ').convert(rows)}\n';
    expect(rows, isNotEmpty);
    if (Platform.environment['UPDATE_IOS_FIXTURES'] == '1') {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(expected);
      return;
    }
    expect(
      file.readAsStringSync(),
      expected,
      reason:
          'The iOS search catalog is stale. Run: UPDATE_IOS_FIXTURES=1 '
          'flutter test test/tool/dump_search_catalog_test.dart',
    );
  });
}
