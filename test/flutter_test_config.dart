import 'dart:async';

import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';

/// Widget tests run on a fake clock that never runs other isolates: build
/// the city search index inline (test/unit/city_search_index_test.dart
/// checks the background isolate).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PanchangLocationStore.buildIndexInline = true;
  await testMain();
}
