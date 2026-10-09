import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_language.dart';
import '../../models/calendar_entry.dart';
import '../panchang/panchang_city.dart';
import '../panchang/panchang_models.dart';
import '../panchang/panchang_terms.dart';
import '../search/search_catalog.dart';

/// What an event reminder is for (docs/ROADMAP.md Phase 7): a Panchang
/// observance from the search catalogue (a festival or a monthly day such as
/// Amavasya), or every entry of one of the user's calendars. Mirrors
/// ios-native EventReminders.swift.
class EventReminderTarget {
  const EventReminderTarget.observance(String key)
    : _kind = 'observance',
      _value = key,
      source = null;

  const EventReminderTarget.calendar(CalendarEntrySource this.source)
    : _kind = 'calendar',
      _value = '';

  final String _kind;
  final String _value;

  /// The calendar whose entries are reminded, for a calendar reminder.
  final CalendarEntrySource? source;

  /// The catalogue key, for an observance reminder.
  String? get observanceKey => source == null ? _value : null;

  /// "observance:amavasya", "calendar:custom": the stored form and the id.
  String get key =>
      source == null ? '$_kind:$_value' : '$_kind:${source!.name}';

  /// Panchang observances are calculated, so they are Premium like Key days.
  bool get requiresPremium => source == null;

  static EventReminderTarget? parse(String key) {
    final index = key.indexOf(':');
    if (index <= 0 || index == key.length - 1) return null;
    final value = key.substring(index + 1);
    switch (key.substring(0, index)) {
      case 'observance':
        return EventReminderTarget.observance(value);
      case 'calendar':
        for (final source in CalendarEntrySource.values) {
          if (source.name == value) return EventReminderTarget.calendar(source);
        }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is EventReminderTarget && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// One reminder: its event, how many days before (0 is the day itself) and
/// the time of day, on the event's own clock.
class EventReminder {
  static const leadDays = [0, 1, 2, 3, 7];

  /// Devotees plan a day or two ahead.
  static const defaultLeadDays = [1, 2];

  EventReminder({
    required this.target,
    List<int> daysBefore = defaultLeadDays,
    int hour = 7,
    int minute = 0,
  }) : daysBefore = List.unmodifiable(
         daysBefore.where((d) => d >= 0 && d <= 30).toSet().toList()..sort(),
       ),
       hour = hour.clamp(0, 23),
       minute = minute.clamp(0, 59);

  final EventReminderTarget target;

  /// Distinct, ascending.
  final List<int> daysBefore;
  final int hour;
  final int minute;

  String get id => target.key;

  /// The same keys as the iOS app's Codable form, sorted.
  Map<String, Object> toJson() => {
    'daysBefore': daysBefore,
    'hour': hour,
    'minute': minute,
    'target': target.key,
  };

  static EventReminder? fromJson(Object? json) {
    if (json is! Map) return null;
    final target = EventReminderTarget.parse('${json['target']}');
    final days = json['daysBefore'];
    if (target == null || days is! List) return null;
    return EventReminder(
      target: target,
      daysBefore: [
        for (final d in days)
          if (d is int) d,
      ],
      hour: json['hour'] is int ? json['hour'] as int : 7,
      minute: json['minute'] is int ? json['minute'] as int : 0,
    );
  }

  EventReminder copyWith({List<int>? daysBefore, int? hour, int? minute}) =>
      EventReminder(
        target: target,
        daysBefore: daysBefore ?? this.daysBefore,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  @override
  bool operator ==(Object other) =>
      other is EventReminder &&
      other.target == target &&
      other.hour == hour &&
      other.minute == minute &&
      other.daysBefore.length == daysBefore.length &&
      Iterable.generate(
        daysBefore.length,
      ).every((i) => other.daysBefore[i] == daysBefore[i]);

  @override
  int get hashCode =>
      Object.hash(target, hour, minute, Object.hashAll(daysBefore));
}

/// The reminders the user chose, stored as JSON under [prefsKey]. [enabled]
/// is the master Notifications switch they share with the Ekadashi reminders.
class EventReminderSettings {
  EventReminderSettings({this.enabled = true, List<EventReminder>? reminders})
    : reminders = List.unmodifiable(reminders ?? const []);

  static const prefsKey = 'event_reminders';

  final bool enabled;
  final List<EventReminder> reminders;

  /// Unreadable data reads as no reminders.
  static EventReminderSettings decode(String? json, {bool enabled = true}) {
    var reminders = <EventReminder>[];
    if (json != null) {
      try {
        final list = jsonDecode(json);
        if (list is List) {
          reminders = [for (final row in list) ?EventReminder.fromJson(row)];
        }
      } on FormatException {
        reminders = [];
      }
    }
    return EventReminderSettings(enabled: enabled, reminders: reminders);
  }

  String encode() => jsonEncode([for (final r in reminders) r.toJson()]);

  EventReminder? reminderFor(EventReminderTarget target) {
    for (final r in reminders) {
      if (r.target == target) return r;
    }
    return null;
  }

  /// Adds [reminder], or replaces the one for the same event.
  EventReminderSettings upsert(EventReminder reminder) {
    final index = reminders.indexWhere((r) => r.id == reminder.id);
    final updated = [...reminders];
    if (index >= 0) {
      updated[index] = reminder;
    } else {
      updated.add(reminder);
    }
    return EventReminderSettings(enabled: enabled, reminders: updated);
  }

  EventReminderSettings remove(EventReminderTarget target) =>
      EventReminderSettings(
        enabled: enabled,
        reminders: reminders.where((r) => r.target != target).toList(),
      );

  EventReminderSettings withEnabled(bool value) =>
      EventReminderSettings(enabled: value, reminders: reminders);

  @override
  bool operator ==(Object other) =>
      other is EventReminderSettings &&
      other.enabled == enabled &&
      other.reminders.length == reminders.length &&
      Iterable.generate(
        reminders.length,
      ).every((i) => other.reminders[i] == reminders[i]);

  @override
  int get hashCode => Object.hash(enabled, Object.hashAll(reminders));
}

class PlannedEventReminder {
  const PlannedEventReminder({
    required this.id,
    required this.target,
    required this.eventDate,
    required this.fireDate,
    required this.title,
    required this.body,
    required this.url,
  });

  /// "event.observance:amavasya.2026-10-10.1": stable across plans.
  final String id;
  final EventReminderTarget target;
  final DateTime eventDate;
  final DateTime fireDate;
  final String title;
  final String body;

  /// The deep link the notification opens.
  final String url;
}

String _iso(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Plans event reminders, soonest first within [limit]. Panchang reminders
/// need Premium; calendar reminders are free. The app plans again on launch
/// and whenever reminders, entries, the Panchang location or Premium change.
class EventReminderPlanner {
  const EventReminderPlanner._();

  /// How many event reminders are kept scheduled at once.
  static const pendingLimit = 64;

  /// [observances] are calculated at [observanceCity] and fire on its clock;
  /// entries fire on [entryZone], the phone's clock when null.
  static List<PlannedEventReminder> plan({
    required EventReminderSettings settings,
    required List<DatedObservance> observances,
    required List<CalendarEntry> entries,
    required PanchangCity observanceCity,
    tz.Location? entryZone,
    required String language,
    required bool premium,
    required DateTime now,
    int limit = pendingLimit,
    SearchCatalog? catalog,
  }) {
    if (!settings.enabled || limit <= 0) return const [];
    final source = catalog ?? SearchCatalog.bundled;
    final observanceDays = <String, List<DateTime>>{};
    for (final dated in observances) {
      if (source.excludedEngineIds.contains(dated.observance.id)) continue;
      final entry = source.observance(
        dated.observance.id,
        dated.observance.name,
      );
      if (entry == null) continue;
      final days = observanceDays.putIfAbsent(entry.key, () => []);
      final day = DateTime.utc(
        dated.date.year,
        dated.date.month,
        dated.date.day,
      );
      if (!days.contains(day)) days.add(day);
    }
    final result = <PlannedEventReminder>[];
    for (final reminder in settings.reminders) {
      final target = reminder.target;
      if (target.requiresPremium && !premium) continue;
      final key = target.observanceKey;
      if (key != null) {
        final entry = source.observanceByKey(key);
        if (entry == null) continue;
        final name = entry.name(language);
        for (final day in observanceDays[key] ?? const <DateTime>[]) {
          result.addAll(
            _planned(
              reminder,
              name: name,
              day: day,
              at: (d, h, m) => tz.TZDateTime(
                observanceCity.zone,
                d.year,
                d.month,
                d.day,
                h,
                m,
              ),
              url: 'ekadashi://panchang?date=${_iso(day)}',
              language: language,
              now: now,
            ),
          );
        }
      } else {
        for (final item in entries.where((e) => e.source == target.source)) {
          final start = item.isAllDay
              ? item.startAt
              : entryZone == null
              ? item.startAt.toLocal()
              : tz.TZDateTime.from(item.startAt, entryZone);
          final day = DateTime.utc(start.year, start.month, start.day);
          result.addAll(
            _planned(
              reminder,
              name: item.title,
              day: day,
              at: (d, h, m) => entryZone == null
                  ? DateTime(d.year, d.month, d.day, h, m)
                  : tz.TZDateTime(entryZone, d.year, d.month, d.day, h, m),
              url: 'ekadashi://calendar?date=${_iso(day)}',
              language: language,
              now: now,
              entryId: item.id,
            ),
          );
        }
      }
    }
    result.sort((a, b) {
      final byTime = a.fireDate.compareTo(b.fireDate);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return result.take(limit).toList();
  }

  static List<PlannedEventReminder> _planned(
    EventReminder reminder, {
    required String name,
    required DateTime day,
    required DateTime Function(DateTime day, int hour, int minute) at,
    required String url,
    required String language,
    required DateTime now,
    String? entryId,
  }) => [
    for (final lead in reminder.daysBefore)
      if (at(
        day.subtract(Duration(days: lead)),
        reminder.hour,
        reminder.minute,
      ).isAfter(now))
        PlannedEventReminder(
          id: [
            'event',
            reminder.target.key,
            ?entryId,
            _iso(day),
            '$lead',
          ].join('.'),
          target: reminder.target,
          eventDate: day,
          fireDate: at(
            day.subtract(Duration(days: lead)),
            reminder.hour,
            reminder.minute,
          ).toUtc(),
          title: name,
          body: body(name: name, day: day, lead: lead, language: language),
          url: url,
        ),
  ];

  /// "Amavasya is tomorrow (Sat, 10 Oct 2026)".
  static String body({
    required String name,
    required DateTime day,
    required int lead,
    required String language,
  }) => AppStrings.translateWithArgs(
    lead == 0
        ? 'event_reminder_today'
        : lead == 1
        ? 'event_reminder_tomorrow'
        : 'event_reminder_in_days',
    language,
    [name, PanchangFormat.date(day, language), '$lead'],
  );
}

enum EventReminderGroup {
  festival('festival'),
  monthly('monthly'),
  myCalendar('my_calendar');

  const EventReminderGroup(this.raw);
  final String raw;
  String get titleKey => 'event_reminder_group_$raw';
}

/// The events a reminder can be set for, in the app language: festivals
/// (alphabetical), monthly days (catalogue order) and the user's calendars.
class EventReminderChoice {
  const EventReminderChoice({
    required this.target,
    required this.title,
    required this.group,
  });

  final EventReminderTarget target;
  final String title;
  final EventReminderGroup group;

  String get id => target.key;
  bool get requiresPremium => target.requiresPremium;

  static List<EventReminderChoice> all(
    String language, {
    SearchCatalog? catalog,
  }) {
    final source = catalog ?? SearchCatalog.bundled;
    final festivals = <EventReminderChoice>[];
    final monthly = <EventReminderChoice>[];
    for (final entry in source.observances) {
      if (source.excludedEngineIds.contains(entry.engineId)) continue;
      final festival = entry.categories.contains(SearchCategory.festival);
      final choice = EventReminderChoice(
        target: EventReminderTarget.observance(entry.key),
        title: entry.name(language),
        group: festival
            ? EventReminderGroup.festival
            : EventReminderGroup.monthly,
      );
      (festival ? festivals : monthly).add(choice);
    }
    festivals.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    final calendars = [
      for (final source in CalendarEntrySource.values)
        EventReminderChoice(
          target: EventReminderTarget.calendar(source),
          title: AppStrings.translate(
            'event_reminder_all_${source.name}',
            language,
          ),
          group: EventReminderGroup.myCalendar,
        ),
    ];
    return [...festivals, ...monthly, ...calendars];
  }

  /// The title of a stored reminder's event.
  static String titleFor(
    EventReminderTarget target,
    String language, {
    SearchCatalog? catalog,
  }) {
    final key = target.observanceKey;
    if (key == null) {
      return AppStrings.translate(
        'event_reminder_all_${target.source!.name}',
        language,
      );
    }
    return (catalog ?? SearchCatalog.bundled)
            .observanceByKey(key)
            ?.name(language) ??
        key;
  }
}
