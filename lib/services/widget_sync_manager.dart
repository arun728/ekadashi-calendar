import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'ekadashi_service.dart';
import 'language_service.dart';
import 'native_widget_service.dart';

/// One canonical payload builder for all three Android widget providers.
class WidgetSyncManager {
  static const schemaVersion = 2;
  static String toUtcIsoString(String? value) =>
      DateTime.tryParse(value ?? '')?.toUtc().toIso8601String() ?? '';
  Future<bool> syncWidgetData({
    required List<EkadashiDate> ekadashiList,
    required String timezone,
    required String locationName,
    required LanguageService languageService,
    String tradition = 'General',
    DateTime? now,
  }) async {
    if (ekadashiList.isEmpty) return false;
    final snapshot = buildPayload(
      ekadashiList: ekadashiList,
      timezone: timezone,
      locationName: locationName,
      languageService: languageService,
      tradition: tradition,
      now: now,
    );
    return NativeWidgetService().sendWidgetPayload(jsonEncode(snapshot));
  }

  Map<String, dynamic> buildPayload({
    required List<EkadashiDate> ekadashiList,
    required String timezone,
    required String locationName,
    required LanguageService languageService,
    String tradition = 'General',
    DateTime? now,
  }) {
    final clock = (now ?? DateTime.now()).toUtc(),
        locale = languageService.currentLocale.languageCode;
    final zone =
        {
          'IST': 'Asia/Kolkata',
          'EST': 'America/New_York',
          'CST': 'America/Chicago',
          'MST': 'America/Denver',
          'PST': 'America/Los_Angeles',
        }[timezone] ??
        timezone;
    final local = tz.TZDateTime.from(clock, tz.getLocation(zone));
    final events = List<EkadashiDate>.of(ekadashiList)
      ..sort((a, b) => a.date.compareTo(b.date));
    final future = events.where((e) {
      final end = DateTime.tryParse(e.paranaEndIso);
      return end != null && clock.isBefore(end);
    }).toList();
    final next = future.isEmpty ? null : future.first;
    final today = events
        .where(
          (e) =>
              e.date.year == local.year &&
              e.date.month == local.month &&
              e.date.day == local.day,
        )
        .firstOrNull;
    Map<String, dynamic> item(EkadashiDate e) {
      final state = _state(e, clock),
          fs = toUtcIsoString(e.fastingStartIso),
          ps = toUtcIsoString(e.paranaStartIso),
          pe = toUtcIsoString(e.paranaEndIso);
      final target = state == 'FASTING_ACTIVE'
          ? ps
          : state == 'PARANA_AVAILABLE'
          ? pe
          : fs;
      return {
        'id': e.id,
        'occurrenceUid': e.occurrenceUid,
        'year': e.date.year,
        'name': e.name,
        'localizedName': e.name,
        'date': DateFormat('yyyy-MM-dd').format(e.date),
        'dateISO': DateFormat('yyyy-MM-dd').format(e.date),
        'localizedDate': DateFormat('d MMM yyyy', locale).format(e.date),
        'paksha': e.paksha,
        'month': e.month,
        'fastingStartUTC': fs,
        'fastingEndUTC': ps,
        'paranaStartUTC': ps,
        'paranaEndUTC': pe,
        'targetTimestampUTC': target,
        'countdownTarget': target,
        'description': e.description,
      };
    }

    final strings = <String, String>{};
    const keys = {
      'title': 'app_title',
      'next_ekadashi': 'next_ekadashi',
      'fasting_active': 'fasting_active',
      'parana_available': 'parana_available',
      'parana_completed': 'parana_completed',
      'open_app_to_refresh': 'open_app_to_refresh',
      'fasting_starts': 'start_fasting',
      'parana_window': 'break_fasting',
      'upcoming_ekadashis': 'upcoming_ekadashis',
      'today': 'today',
      'tomorrow': 'tomorrow',
      'days_remaining': 'in_days',
      'view_details': 'view_details',
      'today_title': 'widget_today_title',
      'parana_in': 'widget_parana_in',
      'parana_ends': 'widget_parana_ends',
      'starts_in': 'widget_starts_in',
      'notice': 'widget_notice',
      'now': 'widget_now',
      'day_unit': 'widget_day_unit',
      'hour_unit': 'widget_hour_unit',
      'minute_unit': 'widget_minute_unit',
      'no_ekadashi': 'no_ekadashi',
    };
    keys.forEach(
      (key, value) => strings['widget.$key'] = languageService.translate(value),
    );
    final upcoming = future.skip(1).map(item).toList();
    return {
      'metadata': {
        'schemaVersion': schemaVersion,
        'dataVersion': '2.0.0',
        'generatedAtUTC': clock.toIso8601String(),
        'lastUpdatedAtUTC': clock.toIso8601String(),
        'lastSuccessfulCalculationUTC': clock.toIso8601String(),
        'locale': locale,
        'timezone': zone,
        'locationName': locationName,
        'tradition': tradition,
        'calculationVersion': 'bundled-v2',
        'cacheStatus': 'VALID',
      },
      'currentState': next == null ? 'FALLBACK' : _state(next, clock),
      'nextEkadashi': next == null ? null : item(next),
      'today': {
        'isEkadashi': today != null,
        'name': today?.name ?? '',
        'fastingStatus': today == null
            ? 'NO_EKADASHI_TODAY'
            : _state(today, clock),
        'state': today == null ? 'NO_EKADASHI_TODAY' : _state(today, clock),
        'fastingStartUTC': toUtcIsoString(today?.fastingStartIso),
        'paranaStartUTC': toUtcIsoString(today?.paranaStartIso),
        'paranaEndUTC': toUtcIsoString(today?.paranaEndIso),
      },
      'upcoming': upcoming,
      'upcomingEkadashis': upcoming,
      'localizedStrings': strings,
    };
  }

  String _state(EkadashiDate e, DateTime now) {
    final fs = DateTime.tryParse(e.fastingStartIso),
        ps = DateTime.tryParse(e.paranaStartIso),
        pe = DateTime.tryParse(e.paranaEndIso);
    if (fs == null || ps == null || pe == null) return 'FALLBACK';
    if (now.isBefore(fs)) return 'BEFORE_EKADASHI';
    if (now.isBefore(ps)) return 'FASTING_ACTIVE';
    if (now.isBefore(pe)) return 'PARANA_AVAILABLE';
    return 'PARANA_COMPLETED';
  }
}
