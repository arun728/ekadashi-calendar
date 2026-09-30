import 'calendar_entry.dart';

/// One row in the selected-day list.
enum DayItemKind { ekadashi, custom, google }

class DayListItem {
  final DayItemKind kind;
  final String title;
  final String? subtitle;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isAllDay;
  final String? entryId; // null for ekadashi
  final bool editable;

  const DayListItem({
    required this.kind,
    required this.title,
    this.subtitle,
    this.startAt,
    this.endAt,
    this.isAllDay = true,
    this.entryId,
    required this.editable,
  });
}

/// Pure merge + filter logic for regression safety.
class CalendarDayMerge {
  /// Filter order in UI: All, Ekadashi, Google, Custom.
  static const filterOrder = [
    CalendarFilter.all,
    CalendarFilter.ekadashi,
    CalendarFilter.google,
    CalendarFilter.custom,
  ];

  static const defaultFilter = CalendarFilter.ekadashi;

  static List<DayListItem> merge({
    required DateTime day,
    required List<({String name, String? description})> ekadashis,
    required List<CalendarEntry> entries,
    required CalendarFilter filter,
  }) {
    final items = <DayListItem>[];

    final showEkadashi =
        filter == CalendarFilter.all || filter == CalendarFilter.ekadashi;
    final showGoogle =
        filter == CalendarFilter.all || filter == CalendarFilter.google;
    final showCustom =
        filter == CalendarFilter.all || filter == CalendarFilter.custom;

    if (showEkadashi) {
      for (final e in ekadashis) {
        items.add(DayListItem(
          kind: DayItemKind.ekadashi,
          title: e.name,
          subtitle: e.description,
          isAllDay: true,
          editable: false,
        ));
      }
    }

    final dayEntries = entries.where((e) => e.occursOn(day)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    for (final e in dayEntries) {
      if (e.source == CalendarEntrySource.google && !showGoogle) continue;
      if (e.source == CalendarEntrySource.custom && !showCustom) continue;
      items.add(DayListItem(
        kind: e.source == CalendarEntrySource.google
            ? DayItemKind.google
            : DayItemKind.custom,
        title: e.title,
        subtitle: e.notes,
        startAt: e.startAt,
        endAt: e.endAt,
        isAllDay: e.isAllDay,
        entryId: e.id,
        editable: e.source == CalendarEntrySource.custom,
      ));
    }

    return items;
  }
}
