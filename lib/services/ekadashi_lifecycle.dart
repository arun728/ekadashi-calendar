import 'dart:math' as math;
import 'package:timezone/timezone.dart' as tz;
import '../l10n/app_language.dart';
import 'ekadashi_service.dart';

enum EkadashiPhase {
  scheduled,
  countdown,
  fasting,
  parana,
  passed,
  unavailable,
}

/// Matches iOS: completion ends at Parana start, selection at Parana end.
class EkadashiLifecycle {
  EkadashiLifecycle._(
    this.phase,
    this.progress,
    this.secondsUntilStart,
    this.daysUntil,
  );
  final EkadashiPhase phase;
  final double? progress;
  final int secondsUntilStart;
  final int daysUntil;
  static tz.Location zone(String name) {
    try {
      return tz.getLocation(
        const {
              'IST': 'Asia/Kolkata',
              'EST': 'America/New_York',
              'CST': 'America/Chicago',
              'MST': 'America/Denver',
              'PST': 'America/Los_Angeles',
            }[name] ??
            name,
      );
    } catch (_) {
      return tz.UTC;
    }
  }

  static DateTime localDay(DateTime now, String timezone) {
    final local = tz.TZDateTime.from(now, zone(timezone));
    return DateTime(local.year, local.month, local.day);
  }

  factory EkadashiLifecycle.of(
    EkadashiDate event,
    DateTime now,
    String timezone,
  ) {
    final today = localDay(now, timezone);
    final days = DateTime.utc(
      event.date.year,
      event.date.month,
      event.date.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    final start = DateTime.tryParse(event.fastingStartIso),
        parana = DateTime.tryParse(event.paranaStartIso),
        end = DateTime.tryParse(event.paranaEndIso);
    if (start == null ||
        parana == null ||
        end == null ||
        !parana.isAfter(start) ||
        end.isBefore(parana)) {
      return EkadashiLifecycle._(EkadashiPhase.unavailable, null, 0, days);
    }
    final seconds = math.max(
      0,
      (start.difference(now).inMicroseconds / 1000000).ceil(),
    );
    if (now.isBefore(start)) {
      return EkadashiLifecycle._(
        days <= 0 ? EkadashiPhase.countdown : EkadashiPhase.scheduled,
        null,
        seconds,
        days,
      );
    }
    if (now.isBefore(parana)) {
      return EkadashiLifecycle._(
        EkadashiPhase.fasting,
        (now.difference(start).inMicroseconds /
                parana.difference(start).inMicroseconds)
            .clamp(0.0, 1.0),
        seconds,
        days,
      );
    }
    if (now.isBefore(end)) {
      return EkadashiLifecycle._(EkadashiPhase.parana, 1, seconds, days);
    }
    return EkadashiLifecycle._(EkadashiPhase.passed, null, seconds, days);
  }
  int? get percent => progress == null
      ? null
      : math.min(100, (progress! * 100 + 0.000000001).floor());
  String get countdown => [
    secondsUntilStart ~/ 3600,
    secondsUntilStart ~/ 60 % 60,
    secondsUntilStart % 60,
  ].map((v) => v.toString().padLeft(2, '0')).join(':');
  String label(String language) => switch (phase) {
    EkadashiPhase.countdown => countdown,
    EkadashiPhase.fasting => AppStrings.translate('widget_now', language),
    EkadashiPhase.parana => AppStrings.translate('panchang_parana', language),
    EkadashiPhase.passed => AppStrings.translate('passed', language),
    _ =>
      daysUntil < 0
          ? AppStrings.translate('passed', language)
          : daysUntil == 1
          ? AppStrings.translate('tomorrow', language)
          : AppStrings.translate(
              'in_days',
              language,
            ).replaceAll('{value0}', math.max(0, daysUntil).toString()),
  };
  static int currentIndex(
    List<EkadashiDate> events,
    DateTime now,
    String timezone,
  ) {
    final day = localDay(now, timezone);
    final index = events.indexWhere((e) {
      final end = DateTime.tryParse(e.paranaEndIso);
      return end != null ? now.isBefore(end) : !e.date.isBefore(day);
    });
    return index < 0 ? math.max(0, events.length - 1) : index;
  }

  static bool hasParana(EkadashiDate event, DateTime day, String timezone) {
    final start = DateTime.tryParse(event.paranaStartIso),
        end = DateTime.tryParse(event.paranaEndIso);
    if (start == null || end == null || end.isBefore(start)) return false;
    final first = localDay(start, timezone),
        last = localDay(
          end == start ? end : end.subtract(const Duration(microseconds: 1)),
          timezone,
        );
    final date = DateTime(day.year, day.month, day.day);
    return !date.isBefore(first) && !date.isAfter(last);
  }

  Duration nextDelay(EkadashiDate event, DateTime now, String timezone) {
    final cadence = Duration(
      seconds: phase == EkadashiPhase.countdown
          ? 1
          : phase == EkadashiPhase.scheduled
          ? 3600
          : 60,
    );
    final date = tz.TZDateTime(
      zone(timezone),
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final targets =
        [
              date,
              DateTime.tryParse(event.fastingStartIso),
              DateTime.tryParse(event.paranaStartIso),
              DateTime.tryParse(event.paranaEndIso),
            ]
            .whereType<DateTime>()
            .where((t) => t.isAfter(now))
            .map((t) => t.difference(now));
    return targets.fold(cadence, (a, b) => a < b ? a : b);
  }
}

class EkadashiCalendarDay {
  EkadashiCalendarDay(List<EkadashiDate> events, DateTime day, String timezone)
    : fasting = events
          .where(
            (e) =>
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day,
          )
          .toList(),
      parana = events
          .where(
            (e) =>
                !(e.date.year == day.year &&
                    e.date.month == day.month &&
                    e.date.day == day.day) &&
                EkadashiLifecycle.hasParana(e, day, timezone),
          )
          .toList();
  final List<EkadashiDate> fasting, parana;
  bool get showsFastingMarker => fasting.isNotEmpty;
}
