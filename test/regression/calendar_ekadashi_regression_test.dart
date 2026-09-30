import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/models/calendar_day_merge.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';

/// Ensures new calendar features do not break official Ekadashi data/UX contracts.
void main() {
  late List<dynamic> ekadashis;

  setUpAll(() {
    final file = File('assets/ekadashi_data.json');
    final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    ekadashis = data['ekadashis'] as List<dynamic>;
  });

  test('JSON still has 24 Ekadashis for 2027', () {
    expect(ekadashis.length, 24);
    for (final e in ekadashis) {
      expect((e['timing']['IST']['date'] as String).startsWith('2027-'), isTrue);
    }
  });

  test('Ekadashi rows are never marked editable in merge', () {
    final day = DateTime(2027, 1, 3);
    final items = CalendarDayMerge.merge(
      day: day,
      ekadashis: [(name: 'Saphala Ekadashi', description: 'desc')],
      entries: [
        CalendarEntry(
          id: 'c',
          title: 'Custom',
          startAt: day,
          endAt: day.add(const Duration(hours: 1)),
          source: CalendarEntrySource.custom,
          updatedAt: day,
        ),
      ],
      filter: CalendarFilter.all,
    );
    for (final i in items.where((x) => x.kind == DayItemKind.ekadashi)) {
      expect(i.editable, isFalse);
      expect(i.entryId, isNull);
    }
  });

  test('default filter remains Ekadashi so home calendar UX unchanged by default', () {
    expect(CalendarDayMerge.defaultFilter, CalendarFilter.ekadashi);
  });

  test('calendar_screen still targets 2027 range', () {
    final src = File('lib/screens/calendar_screen.dart').readAsStringSync();
    expect(src.contains('DateTime(2027, 1, 1)'), isTrue);
    expect(src.contains('DateTime(2027, 12, 31)'), isTrue);
  });

  test('Ekadashi teal accent color unchanged', () {
    expect(CalendarMarkerColors.ekadashiTeal, 0xFF00A19B);
  });
}
