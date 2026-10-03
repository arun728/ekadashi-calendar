import 'dart:convert';
import 'package:flutter/services.dart';

/// Calendar providers return immutable packs; generated dates can implement the
/// same boundary without changing browsing or user-history identities.
abstract interface class CalendarDataSource {
  Future<List<Map<String, dynamic>>> loadYearPacks();
}

class BundledCalendarSource implements CalendarDataSource {
  final AssetBundle bundle;
  BundledCalendarSource({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  @override
  Future<List<Map<String, dynamic>>> loadYearPacks() async {
    final manifest =
        jsonDecode(await bundle.loadString('assets/calendar/manifest.json'))
            as Map<String, dynamic>;
    if (manifest['schema_version'] != 1) {
      throw const FormatException('Unsupported calendar manifest');
    }
    final packs = <Map<String, dynamic>>[];
    for (final item in manifest['packs'] as List) {
      final pack =
          jsonDecode(await bundle.loadString(item['asset'] as String))
              as Map<String, dynamic>;
      if (pack['year'] != item['year']) {
        throw const FormatException('Calendar pack year differs from manifest');
      }
      packs.add(pack);
    }
    return packs;
  }
}

class CalendarRepository {
  final CalendarDataSource source;
  List<Map<String, dynamic>> _packs = const [];
  bool _loaded = false;

  CalendarRepository({CalendarDataSource? source})
    : source = source ?? BundledCalendarSource();

  List<int> get availableYears =>
      (_packs.map((p) => p['year'] as int).toSet().toList()..sort());

  Future<void> load() async {
    if (_loaded) return;
    final packs = await source.loadYearPacks();
    final years = <int>{};
    final uids = <String>{};
    final nativeIds = <int>{};
    for (final pack in packs) {
      final year = pack['year'] as int;
      if (pack['schema_version'] != 1 || !years.add(year)) {
        throw const FormatException('Unsupported or duplicate calendar year');
      }
      for (final row in pack['ekadashis'] as List) {
        final uid = row['occurrence_uid'] as String;
        final nativeId = row['notification_id'] as int;
        if (!uid.startsWith('ekadashi:$year:') ||
            !uids.add(uid) ||
            nativeId <= 0 ||
            nativeId > 0x7fffffff ||
            !nativeIds.add(nativeId)) {
          throw const FormatException('Invalid or duplicate calendar identity');
        }
        if (row['name']['en'] is! String ||
            (row['name']['en'] as String).trim().isEmpty) {
          throw const FormatException('Calendar occurrence has no source name');
        }
        for (final timing in (row['timing'] as Map).values) {
          final date = DateTime.tryParse(timing['date'] as String);
          final start = DateTime.tryParse(timing['fasting_start'] as String);
          final parana = DateTime.tryParse(timing['parana_start'] as String);
          final end = DateTime.tryParse(timing['parana_end'] as String);
          if (date == null ||
              start == null ||
              parana == null ||
              end == null ||
              !parana.isAfter(start) ||
              !end.isAfter(parana)) {
            throw const FormatException('Invalid calendar occurrence timing');
          }
        }
      }
    }
    // Publish only after every pack validates. A failed load can be retried.
    _packs = List.unmodifiable(
      (jsonDecode(jsonEncode(packs)) as List).cast<Map<String, dynamic>>(),
    );
    _loaded = true;
  }

  /// Adapter for existing display parsing. The integer is a permanent native
  /// notification ID; occurrence_uid is the durable cross-year domain identity.
  Map<String, dynamic> combinedData() =>
      jsonDecode(
            jsonEncode({
              'version': 'multi-year-1',
              'ekadashis': [
                for (final pack in _packs)
                  for (final row in pack['ekadashis'] as List)
                    {
                      ...Map<String, dynamic>.from(row as Map),
                      'id': row['notification_id'],
                      'calendar_year': pack['year'],
                    },
              ],
            }),
          )
          as Map<String, dynamic>;
}
