import 'package:timezone/timezone.dart' as tz;

import 'ekadashi_service.dart';

/// When a fast can be recorded (docs/ROADMAP.md Phase 4), like the Swift
/// `VratRecording`: once it is over. A past Ekadashi is open; today's opens
/// when its Parana begins; a future one stays closed.
class VratRecording {
  const VratRecording._();

  static const _zones = {
    'IST': 'Asia/Kolkata',
    'EST': 'America/New_York',
    'CST': 'America/Chicago',
    'MST': 'America/Denver',
    'PST': 'America/Los_Angeles',
  };

  /// [timezone] is the schedule's zone (IST, EST, ...) or an IANA name.
  static bool isOpen(
    EkadashiDate event, {
    required DateTime now,
    required String timezone,
  }) {
    final parana = DateTime.tryParse(event.paranaStartIso);
    if (parana != null) return !now.isBefore(parana);
    DateTime today;
    try {
      final local = tz.TZDateTime.from(
        now,
        tz.getLocation(_zones[timezone] ?? timezone),
      );
      today = DateTime(local.year, local.month, local.day);
    } catch (_) {
      final local = now.toLocal();
      today = DateTime(local.year, local.month, local.day);
    }
    final day = DateTime(event.date.year, event.date.month, event.date.day);
    return today.isAfter(day);
  }
}
