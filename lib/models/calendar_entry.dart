/// User or imported calendar entry (not official Ekadashi rows).
enum CalendarEntrySource { custom, google }

class CalendarEntry {
  final String id;
  final String title;
  final String? notes;
  final DateTime startAt;
  final DateTime endAt;
  final bool isAllDay;
  final CalendarEntrySource source;
  final String? googleEventId;
  final String? calendarName;
  final DateTime updatedAt;

  const CalendarEntry({
    required this.id,
    required this.title,
    this.notes,
    required this.startAt,
    required this.endAt,
    this.isAllDay = false,
    required this.source,
    this.googleEventId,
    this.calendarName,
    required this.updatedAt,
  });

  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startAt.year, startAt.month, startAt.day);
    final end = DateTime(endAt.year, endAt.month, endAt.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  CalendarEntry copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    CalendarEntrySource? source,
    String? googleEventId,
    String? calendarName,
    DateTime? updatedAt,
  }) {
    return CalendarEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isAllDay: isAllDay ?? this.isAllDay,
      source: source ?? this.source,
      googleEventId: googleEventId ?? this.googleEventId,
      calendarName: calendarName ?? this.calendarName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'start_at': startAt.toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'is_all_day': isAllDay ? 1 : 0,
        'source': source.name,
        'google_event_id': googleEventId,
        'calendar_name': calendarName,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CalendarEntry.fromMap(Map<String, dynamic> map) {
    return CalendarEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      startAt: DateTime.parse(map['start_at'] as String),
      endAt: DateTime.parse(map['end_at'] as String),
      isAllDay: (map['is_all_day'] as int) == 1,
      source: CalendarEntrySource.values.byName(map['source'] as String),
      googleEventId: map['google_event_id'] as String?,
      calendarName: map['calendar_name'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Filter for calendar tab. Default is [ekadashi].
enum CalendarFilter { all, ekadashi, google, custom }

/// Marker colors (app accent teal for Ekadashi).
class CalendarMarkerColors {
  static const int ekadashiTeal = 0xFF00A19B;
  static const int googleBlue = 0xFF4285F4;
  static const int customPurple = 0xFF9C27B0;
}
