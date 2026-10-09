import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/calendar_entry.dart';
import '../native_notification_service.dart';
import '../panchang/observance_calendar_service.dart';
import '../panchang/panchang_city.dart';
import '../search/search_catalog.dart';
import 'event_reminders.dart';

/// Hands planned reminders to the platform; returns how many it scheduled.
typedef EventReminderScheduler =
    Future<int> Function(List<PlannedEventReminder> reminders);

/// The user's festival, Panchang and calendar reminders (docs/ROADMAP.md
/// Phase 7): stored under [EventReminderSettings.prefsKey], planned again on
/// launch and resume and whenever reminders, entries, the Panchang location
/// or Premium change. The master Notifications switch is shared with the
/// Ekadashi reminders.
class EventReminderService extends ChangeNotifier {
  EventReminderService({EventReminderScheduler? scheduler})
    : _scheduler =
          scheduler ?? NativeNotificationService().scheduleEventReminders;

  static final instance = EventReminderService();

  final EventReminderScheduler _scheduler;
  EventReminderSettings _settings = EventReminderSettings();
  bool _loaded = false;
  Future<void> Function()? _replan;

  EventReminderSettings get settings => _settings;
  List<EventReminder> get reminders => _settings.reminders;

  Future<EventReminderSettings> load() async {
    if (!_loaded) {
      // Titles and the event picker read the search catalogue.
      await _catalog();
      final prefs = await SharedPreferences.getInstance();
      _settings = EventReminderSettings.decode(
        prefs.getString(EventReminderSettings.prefsKey),
      );
      _loaded = true;
      notifyListeners();
    }
    return _settings;
  }

  static Future<SearchCatalog?> _catalog() async {
    try {
      return await SearchCatalog.load();
    } catch (e) {
      debugPrint('Search catalogue unavailable: $e');
      return null;
    }
  }

  /// The app supplies how to plan again with its current state.
  void attach(Future<void> Function() replan) => _replan = replan;

  /// Entries, the Panchang location or Premium changed.
  Future<void> changed() async => _replan?.call();

  Future<void> upsert(EventReminder reminder) async =>
      _save((await load()).upsert(reminder));

  Future<void> remove(EventReminderTarget target) async =>
      _save((await load()).remove(target));

  Future<void> _save(EventReminderSettings settings) async {
    _settings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(EventReminderSettings.prefsKey, settings.encode());
    notifyListeners();
    await changed();
  }

  /// Plans this year's and next year's reminders and schedules them,
  /// replacing the previous ones; nothing when notifications are off.
  Future<int> schedule({
    required bool enabled,
    required bool premium,
    required String language,
    required PanchangCity city,
    required List<CalendarEntry> entries,
    DateTime? now,
  }) async {
    final settings = (await load()).withEnabled(enabled);
    if (!enabled || settings.reminders.isEmpty) return _send(const []);
    // Without the catalogue nothing can be planned; keep what is scheduled.
    if (await _catalog() == null) return 0;
    final clock = now ?? DateTime.now();
    final needsObservances =
        enabled &&
        premium &&
        settings.reminders.any((r) => r.target.requiresPremium);
    final observances = needsObservances
        ? await ObservanceCalendarService.instance.years([
            clock.year,
            clock.year + 1,
          ], city)
        : const <Never>[];
    final planned = EventReminderPlanner.plan(
      settings: settings,
      observances: observances,
      entries: entries,
      observanceCity: city,
      language: language,
      premium: premium,
      now: clock,
    );
    return _send(planned);
  }

  Future<int> _send(List<PlannedEventReminder> planned) async {
    try {
      return await _scheduler(planned);
    } catch (e) {
      debugPrint('Event reminders not scheduled: $e');
      return 0;
    }
  }
}
