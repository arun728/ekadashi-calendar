import 'dart:async';

import 'package:ekadashi_calendar/l10n/place_names.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';

/// Widget tests run on a fake clock that never runs other isolates: read
/// the city catalog and place names and build the city search index inline
/// (test/unit/city_search_index_test.dart and launch_performance_test.dart
/// check the background isolates).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  PanchangLocationStore.buildIndexInline = true;
  PlaceNames.decodeInline = true;
  await testMain();
}
