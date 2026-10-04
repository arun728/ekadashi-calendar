import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart';
import 'native_settings_service.dart';
import 'practice_service.dart';
import 'premium_service.dart';
import 'language_service.dart';

tz.Location resolvePracticeTimeZone(String name) {
  if (const ['UTC', 'Etc/UTC', 'GMT', 'Etc/GMT'].contains(name)) return tz.UTC;
  return tz.getLocation(name == 'Asia/Calcutta' ? 'Asia/Kolkata' : name);
}

class PracticeReminder {
  const PracticeReminder(this.routine, this.at);
  final PracticeRoutine routine;
  final tz.TZDateTime at;
}

List<PracticeReminder> planPracticeReminders(
  List<PracticeRoutine> routines,
  tz.TZDateTime now, {
  required bool premium,
  required bool permitted,
  int quietStart = 1320,
  int quietEnd = 420,
}) {
  if (!premium || !permitted) return [];
  final events = <PracticeReminder>[];
  for (final routine in routines) {
    final minute = routine.reminderMinute;
    if (minute == null) continue;
    final quiet = quietStart == quietEnd
        ? false
        : quietStart < quietEnd
        ? minute >= quietStart && minute < quietEnd
        : minute >= quietStart || minute < quietEnd;
    if (quiet) continue;
    for (var day = 0; day < 14; day++) {
      final at = tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day + day,
        minute ~/ 60,
        minute % 60,
      );
      if (at.hour != minute ~/ 60 ||
          at.minute != minute % 60 ||
          !at.isAfter(now)) {
        continue;
      }
      if (routine.weekdays.isNotEmpty &&
          !routine.weekdays.contains(at.weekday)) {
        continue;
      }
      events.add(PracticeReminder(routine, at));
    }
  }
  events.sort((a, b) => a.at.compareTo(b.at));
  return events.take(32).toList();
}

/// Own notification IDs; cancellation never touches Ekadashi reminders.
class PracticeReminders {
  PracticeReminders(this.practice, this.premium, this.language) {
    practice.addListener(reconcile);
    premium.addListener(reconcile);
    language.addListener(_localeChanged);
  }
  final PracticeService practice;
  final PremiumService premium;
  final LanguageService language;
  String? _signature;
  Future<void> _tail = Future.value();
  bool _disposed = false;
  String? error;
  void _localeChanged() => reconcile(force: true);
  void reconcile({bool force = false}) {
    if (_disposed || !practice.ready) return;
    final next = jsonEncode([
      practice.routines.map((r) => r.toJson()).toList(),
      practice.quietStart,
      practice.quietEnd,
      premium.isPremium,
    ]);
    if (!force && next == _signature) return;
    _signature = next;
    _tail = _tail.then((_) => _schedule()).catchError((_) {
      error = 'practice_reminder_denied';
      _signature = null;
    });
  }

  Future<void> _schedule() async {
    if (_disposed) return;
    final prefs = await SharedPreferences.getInstance();
    final plugin = NotificationService().flutterLocalNotificationsPlugin;
    // IDs include date and routine, so rebuilds remain deterministic.
    final prior = prefs.getStringList('practice_reminder_ids') ?? [];
    for (final id in prior) {
      await plugin.cancel(int.parse(id));
    }
    await prefs.setStringList('practice_reminder_ids', []);
    final permission = await NativeSettingsService().checkAllPermissions();
    final settings = await NativeSettingsService().getNotificationSettings();
    if (_disposed ||
        !premium.isPremium ||
        !permission.hasNotificationPermission ||
        !settings.enabled) {
      return;
    }
    final name = await FlutterTimezone.getLocalTimezone();
    final zone = resolvePracticeTimeZone(name);
    final events = planPracticeReminders(
      practice.routines,
      tz.TZDateTime.now(zone),
      premium: premium.isPremium,
      permitted: true,
      quietStart: practice.quietStart,
      quietEnd: practice.quietEnd,
    );
    final ids = <String>[];
    for (final event in events) {
      if (_disposed || !premium.isPremium) break;
      final key =
          '${event.routine.id}/${event.at.year}/${event.at.month}/${event.at.day}';
      final hash = key.codeUnits.fold<int>(
        0,
        (a, b) => (a * 31 + b) & 0x1fffffff,
      );
      final id = 1500000000 + hash;
      ids.add('$id');
      // Persist cancellation ownership before scheduling to recover partial failures.
      if (!await prefs.setStringList('practice_reminder_ids', ids)) {
        throw StateError('Reminder storage failed');
      }
      await plugin.zonedSchedule(
        id,
        language.translate('practice_today_shortcut'),
        event.routine.title,
        event.at,
        fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'daily_practice',
            language.translate('devotion_practice'),
            importance: fln.Importance.defaultImportance,
            priority: fln.Priority.defaultPriority,
          ),
          iOS: const fln.DarwinNotificationDetails(),
        ),
        androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            fln.UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'ekadashi://practice',
      );
    }
    error = null;
  }

  void dispose() {
    _disposed = true;
    practice.removeListener(reconcile);
    premium.removeListener(reconcile);
    language.removeListener(_localeChanged);
  }
}
