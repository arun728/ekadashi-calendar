import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'ekadashi_service.dart';
import 'language_service.dart';
import 'native_widget_service.dart';

/// Centralized manager responsible for the lifecycle, transformation,
/// validation, and cross-platform synchronization of Home-Screen Widget data.
class WidgetSyncManager {
  static final WidgetSyncManager _instance = WidgetSyncManager._internal();
  factory WidgetSyncManager() => _instance;
  WidgetSyncManager._internal();

  static const int schemaVersion = 2;

  /// Helper to convert any raw datetime string to strict UTC ISO-8601 ending in 'Z'.
  static String toUtcIsoString(String? rawIso) {
    if (rawIso == null || rawIso.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(rawIso);
      if (dt == null) return '';
      return dt.toUtc().toIso8601String();
    } catch (_) {
      return '';
    }
  }

  /// Synchronize the canonical Ekadashi calculation results to home-screen widgets.
  Future<bool> syncWidgetData({
    required List<EkadashiDate> ekadashiList,
    required String timezone,
    required String locationName,
    required LanguageService languageService,
    String tradition = 'General',
  }) async {
    try {
      if (ekadashiList.isEmpty) {
        debugPrint('⚠️ [WidgetSyncManager] Ekadashi list empty, skipping sync.');
        return false;
      }

      final nowUtc = DateTime.now().toUtc();
      final localeCode = languageService.currentLocale.languageCode;

      // 1. Identify currently active or next upcoming Ekadashi
      EkadashiDate? activeOrNextEkadashi;
      EkadashiDate? todayEkadashi;
      final List<EkadashiDate> futureEkadashis = [];

      for (var ekadashi in ekadashiList) {
        DateTime? pEndUtc;
        DateTime? fStartUtc;
        if (ekadashi.paranaEndIso.isNotEmpty) {
          pEndUtc = DateTime.tryParse(ekadashi.paranaEndIso)?.toUtc();
        }
        if (ekadashi.fastingStartIso.isNotEmpty) {
          fStartUtc = DateTime.tryParse(ekadashi.fastingStartIso)?.toUtc();
        }

        // Check if today matches the Ekadashi calendar date or fasting window
        final nowLocal = DateTime.now();
        final isSameDay = ekadashi.date.year == nowLocal.year &&
            ekadashi.date.month == nowLocal.month &&
            ekadashi.date.day == nowLocal.day;

        final isWithinWindow = (fStartUtc != null && pEndUtc != null) &&
            nowUtc.isAfter(fStartUtc) &&
            nowUtc.isBefore(pEndUtc);

        if (isSameDay || isWithinWindow) {
          todayEkadashi ??= ekadashi;
        }

        // Find next active/upcoming
        if (pEndUtc != null && nowUtc.isBefore(pEndUtc)) {
          activeOrNextEkadashi ??= ekadashi;
        } else if (pEndUtc == null) {
          final eDate = DateTime.utc(ekadashi.date.year, ekadashi.date.month, ekadashi.date.day, 23, 59, 59);
          if (nowUtc.isBefore(eDate)) {
            activeOrNextEkadashi ??= ekadashi;
          }
        }

        // Collect upcoming items
        if (activeOrNextEkadashi != null && ekadashi.id != activeOrNextEkadashi.id) {
          futureEkadashis.add(ekadashi);
        }
      }

      // Fallback if at the end of the yearly calendar
      activeOrNextEkadashi ??= ekadashiList.first;

      // 2. Compute state machine for active Ekadashi
      final currentState = _computeState(activeOrNextEkadashi, nowUtc);

      // 3. Build 'nextEkadashi' block with explicit targetTimestampUTC & countdownTarget
      final nextFastingStartUtc = toUtcIsoString(activeOrNextEkadashi.fastingStartIso);
      final nextParanaStartUtc = toUtcIsoString(activeOrNextEkadashi.paranaStartIso);
      final nextParanaEndUtc = toUtcIsoString(activeOrNextEkadashi.paranaEndIso);

      // Countdown targets fastingStart in BEFORE_EKADASHI, paranaStart in FASTING_ACTIVE, paranaEnd in PARANA_AVAILABLE
      String countdownTargetUtc = nextFastingStartUtc;
      if (currentState == 'FASTING_ACTIVE') {
        countdownTargetUtc = nextParanaStartUtc;
      } else if (currentState == 'PARANA_AVAILABLE') {
        countdownTargetUtc = nextParanaEndUtc;
      }

      final dateIsoStr = DateFormat('yyyy-MM-dd').format(activeOrNextEkadashi.date);
      String localizedDateStr;
      try {
        localizedDateStr = DateFormat('d MMM yyyy', localeCode).format(activeOrNextEkadashi.date);
      } catch (_) {
        localizedDateStr = DateFormat('d MMM yyyy').format(activeOrNextEkadashi.date);
      }

      final Map<String, dynamic> nextEkadashiJson = {
        'id': activeOrNextEkadashi.id,
        'name': activeOrNextEkadashi.name,
        'localizedName': activeOrNextEkadashi.name,
        'date': dateIsoStr,
        'dateISO': dateIsoStr,
        'displayDate': localizedDateStr,
        'localizedDate': localizedDateStr,
        'paksha': activeOrNextEkadashi.paksha,
        'month': activeOrNextEkadashi.month,
        'fastingStartUTC': nextFastingStartUtc,
        'fastingEndUTC': nextParanaStartUtc,
        'paranaStartUTC': nextParanaStartUtc,
        'paranaEndUTC': nextParanaEndUtc,
        'targetTimestampUTC': nextFastingStartUtc,
        'countdownTarget': countdownTargetUtc,
        'description': activeOrNextEkadashi.description,
      };

      // 4. Build 'today' block for Widget B
      final Map<String, dynamic> todayJson;
      if (todayEkadashi != null) {
        final todayState = _computeState(todayEkadashi, nowUtc);
        todayJson = {
          'isEkadashi': true,
          'name': todayEkadashi.name,
          'fastingStatus': todayState,
          'fastingStartUTC': toUtcIsoString(todayEkadashi.fastingStartIso),
          'paranaStartUTC': toUtcIsoString(todayEkadashi.paranaStartIso),
          'paranaEndUTC': toUtcIsoString(todayEkadashi.paranaEndIso),
          'state': todayState,
        };
      } else {
        todayJson = {
          'isEkadashi': false,
          'name': '',
          'fastingStatus': 'No Ekadashi Today',
          'fastingStartUTC': '',
          'paranaStartUTC': '',
          'paranaEndUTC': '',
          'state': 'NO_EKADASHI_TODAY',
        };
      }

      // 5. Build 'upcoming' block for Widget C (take next 10 for scrollable & responsive access)
      final List<Map<String, dynamic>> upcomingJson = futureEkadashis.take(10).map((item) {
        final itemDateIso = DateFormat('yyyy-MM-dd').format(item.date);
        String itemLocalizedDate;
        try {
          itemLocalizedDate = DateFormat('d MMM yyyy', localeCode).format(item.date);
        } catch (_) {
          itemLocalizedDate = DateFormat('d MMM yyyy').format(item.date);
        }

        final itemFastingStartUtc = toUtcIsoString(item.fastingStartIso);

        return {
          'id': item.id,
          'name': item.name,
          'localizedName': item.name,
          'date': itemDateIso,
          'dateISO': itemDateIso,
          'localizedDate': itemLocalizedDate,
          'paksha': item.paksha,
          'timestampUTC': itemFastingStartUtc,
          'fastingStartUTC': itemFastingStartUtc,
          'paranaStartUTC': toUtcIsoString(item.paranaStartIso),
          'paranaEndUTC': toUtcIsoString(item.paranaEndIso),
        };
      }).toList();

      // 6. Localized strings bundle
      final Map<String, String> localizedStrings = {
        'widget.title': languageService.translate('app_title'),
        'widget.next_ekadashi': languageService.translate('next_ekadashi'),
        'widget.fasting_active': languageService.translate('fasting_active'),
        'widget.parana_available': languageService.translate('parana_available'),
        'widget.parana_completed': languageService.translate('parana_completed'),
        'widget.open_app_to_refresh': languageService.translate('open_app_to_refresh'),
        'widget.fasting_starts': languageService.translate('start_fasting'),
        'widget.parana_window': languageService.translate('break_fasting'),
        'widget.upcoming_ekadashis': languageService.translate('upcoming_ekadashis'),
        'widget.today': languageService.translate('today'),
        'widget.tomorrow': languageService.translate('tomorrow'),
        'widget.days_remaining': languageService.translate('in_days'),
        'widget.view_details': languageService.translate('view_details'),
      };

      // 7. Metadata block
      final Map<String, dynamic> metadata = {
        'schemaVersion': schemaVersion,
        'dataVersion': '2.0.0',
        'generatedAtUTC': nowUtc.toIso8601String(),
        'lastUpdatedAtUTC': nowUtc.toIso8601String(),
        'lastSuccessfulCalculationUTC': nowUtc.toIso8601String(),
        'locale': localeCode,
        'timezone': timezone,
        'location': locationName,
        'locationName': locationName,
        'calculationVersion': 'v10.1',
        'tradition': tradition,
        'cacheStatus': 'VALID',
      };

      final Map<String, dynamic> snapshot = {
        'metadata': metadata,
        'currentState': currentState,
        'nextEkadashi': nextEkadashiJson,
        'today': todayJson,
        'upcoming': upcomingJson,
        'upcomingEkadashis': upcomingJson, // backward compatibility
        'localizedStrings': localizedStrings,
      };

      final String snapshotJson = jsonEncode(snapshot);
      debugPrint('📦 [WidgetSyncManager] Synchronizing snapshot (size: ${snapshotJson.length} bytes, next: ${activeOrNextEkadashi.name}).');

      final success = await NativeWidgetService().sendWidgetPayload(snapshotJson);
      if (success) {
        debugPrint('✅ [WidgetSyncManager] Successfully dispatched snapshot to native widget platforms.');
      } else {
        debugPrint('⚠️ [WidgetSyncManager] Native widget dispatch returned false.');
      }
      return success;
    } catch (e, stack) {
      debugPrint('❌ [WidgetSyncManager] Sync failed: $e\n$stack');
      return false;
    }
  }

  String _computeState(EkadashiDate ekadashi, DateTime nowUtc) {
    if (ekadashi.fastingStartIso.isEmpty || ekadashi.paranaStartIso.isEmpty) {
      return 'BEFORE_EKADASHI';
    }

    final fStart = DateTime.tryParse(ekadashi.fastingStartIso)?.toUtc();
    final pStart = DateTime.tryParse(ekadashi.paranaStartIso)?.toUtc();
    final pEnd = DateTime.tryParse(ekadashi.paranaEndIso)?.toUtc();

    if (fStart == null || pStart == null || pEnd == null) {
      return 'BEFORE_EKADASHI';
    }

    if (nowUtc.isBefore(fStart)) {
      return 'BEFORE_EKADASHI';
    } else if (nowUtc.isBefore(pStart)) {
      return 'FASTING_ACTIVE';
    } else if (nowUtc.isBefore(pEnd) || nowUtc.isAtSameMomentAs(pEnd)) {
      return 'PARANA_AVAILABLE';
    } else {
      return 'PARANA_COMPLETED';
    }
  }
}
