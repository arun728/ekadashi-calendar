import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/models/calendar_day_merge.dart';

void main() {
  group('CalendarEntry', () {
    test('occursOn matches single day', () {
      final e = CalendarEntry(
        id: '1',
        title: 'Temple visit',
        startAt: DateTime(2027, 6, 14, 9, 0),
        endAt: DateTime(2027, 6, 14, 10, 0),
        source: CalendarEntrySource.custom,
        updatedAt: DateTime(2027, 1, 1),
      );
      expect(e.occursOn(DateTime(2027, 6, 14)), isTrue);
      expect(e.occursOn(DateTime(2027, 6, 15)), isFalse);
    });

    test('toMap/fromMap round-trip', () {
      final e = CalendarEntry(
        id: 'g1',
        title: 'Meeting',
        notes: 'notes',
        startAt: DateTime(2027, 3, 1, 14, 30),
        endAt: DateTime(2027, 3, 1, 15, 0),
        isAllDay: false,
        source: CalendarEntrySource.google,
        googleEventId: 'evt_123',
        calendarName: 'My calendar',
        updatedAt: DateTime(2027, 3, 1),
      );
      final copy = CalendarEntry.fromMap(e.toMap());
      expect(copy.id, e.id);
      expect(copy.title, e.title);
      expect(copy.googleEventId, 'evt_123');
      expect(copy.source, CalendarEntrySource.google);
      expect(copy.isAllDay, isFalse);
    });
  });

  group('CalendarMarkerColors', () {
    test('Ekadashi is teal accent 0xFF00A19B', () {
      expect(CalendarMarkerColors.ekadashiTeal, 0xFF00A19B);
    });
    test('Google is blue', () {
      expect(CalendarMarkerColors.googleBlue, 0xFF4285F4);
    });
    test('Custom is purple', () {
      expect(CalendarMarkerColors.customPurple, 0xFF9C27B0);
    });
  });

  group('CalendarDayMerge filter order and default', () {
    test('filter order is All, Ekadashi, Google, Custom', () {
      expect(CalendarDayMerge.filterOrder, [
        CalendarFilter.all,
        CalendarFilter.ekadashi,
        CalendarFilter.google,
        CalendarFilter.custom,
      ]);
    });

    test('default filter is Ekadashi', () {
      expect(CalendarDayMerge.defaultFilter, CalendarFilter.ekadashi);
    });
  });

  group('CalendarDayMerge merge + filter', () {
    final day = DateTime(2027, 6, 14);
    final ekadashis = [(name: 'Nirjala Ekadashi', description: 'Waterless fast')];
    final custom = CalendarEntry(
      id: 'c1',
      title: 'Prep fruits',
      startAt: DateTime(2027, 6, 14, 8, 0),
      endAt: DateTime(2027, 6, 14, 9, 0),
      source: CalendarEntrySource.custom,
      updatedAt: DateTime(2027, 1, 1),
    );
    final google = CalendarEntry(
      id: 'g1',
      title: 'Office holiday',
      startAt: DateTime(2027, 6, 14, 0, 0),
      endAt: DateTime(2027, 6, 14, 23, 59),
      isAllDay: true,
      source: CalendarEntrySource.google,
      googleEventId: 'ge1',
      updatedAt: DateTime(2027, 1, 1),
    );

    test('default Ekadashi filter shows only Ekadashi', () {
      final items = CalendarDayMerge.merge(
        day: day,
        ekadashis: ekadashis,
        entries: [custom, google],
        filter: CalendarFilter.ekadashi,
      );
      expect(items.length, 1);
      expect(items.first.kind, DayItemKind.ekadashi);
      expect(items.first.editable, isFalse);
    });

    test('All filter shows Ekadashi + Google + Custom alongside', () {
      final items = CalendarDayMerge.merge(
        day: day,
        ekadashis: ekadashis,
        entries: [custom, google],
        filter: CalendarFilter.all,
      );
      expect(items.length, 3);
      expect(items.map((i) => i.kind).toSet(), {
        DayItemKind.ekadashi,
        DayItemKind.google,
        DayItemKind.custom,
      });
      final ek = items.firstWhere((i) => i.kind == DayItemKind.ekadashi);
      expect(ek.editable, isFalse);
      final cu = items.firstWhere((i) => i.kind == DayItemKind.custom);
      expect(cu.editable, isTrue);
      final go = items.firstWhere((i) => i.kind == DayItemKind.google);
      expect(go.editable, isFalse);
    });

    test('Google filter shows only Google', () {
      final items = CalendarDayMerge.merge(
        day: day,
        ekadashis: ekadashis,
        entries: [custom, google],
        filter: CalendarFilter.google,
      );
      expect(items.length, 1);
      expect(items.first.kind, DayItemKind.google);
    });

    test('Custom filter shows only Custom', () {
      final items = CalendarDayMerge.merge(
        day: day,
        ekadashis: ekadashis,
        entries: [custom, google],
        filter: CalendarFilter.custom,
      );
      expect(items.length, 1);
      expect(items.first.kind, DayItemKind.custom);
    });

    test('entries sorted by startAt within day', () {
      final late = custom.copyWith(
        id: 'c2',
        title: 'Evening aarti',
        startAt: DateTime(2027, 6, 14, 18, 0),
        endAt: DateTime(2027, 6, 14, 19, 0),
      );
      final items = CalendarDayMerge.merge(
        day: day,
        ekadashis: [],
        entries: [late, custom],
        filter: CalendarFilter.custom,
      );
      expect(items.first.title, 'Prep fruits');
      expect(items.last.title, 'Evening aarti');
    });
  });
}
