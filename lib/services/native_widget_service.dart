import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'ekadashi_service.dart';
import 'language_service.dart';

/// Service to bridge Module 10 calculation data into the canonical
/// WidgetData model and synchronize with iOS (App Group) and Android (SharedPreferences).
class NativeWidgetService {
  static final NativeWidgetService _instance = NativeWidgetService._internal();
  factory NativeWidgetService() => _instance;
  NativeWidgetService._internal();

  static const MethodChannel _channel = MethodChannel('com.ekadashi.widget');

  /// Function pointer for incoming deep links
  void Function(Uri)? _deepLinkListener;

  /// Initialize real-time listening for widget deep links
  void initializeDeepLinkListener(void Function(Uri uri) onDeepLink) {
    _deepLinkListener = onDeepLink;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final uriStr = call.arguments as String?;
        if (uriStr != null && uriStr.isNotEmpty) {
          final parsed = Uri.tryParse(uriStr);
          if (parsed != null) {
            debugPrint('📲 NativeWidgetService received deep link from native: $parsed');
            _deepLinkListener?.call(parsed);
          }
        }
      }
      return null;
    });
  }

  /// Retrieve the deep link that launched the app on cold start (if any)
  Future<Uri?> getInitialDeepLink() async {
    try {
      final initialUriStr = await _channel.invokeMethod<String>('getInitialDeepLink');
      if (initialUriStr != null && initialUriStr.isNotEmpty) {
        debugPrint('🚀 NativeWidgetService initial cold-start deep link: $initialUriStr');
        return Uri.tryParse(initialUriStr);
      }
    } catch (e) {
      debugPrint('ℹ️ NativeWidgetService.getInitialDeepLink: $e');
    }
    return null;
  }

  /// Dispatch serialized JSON payload to native iOS and Android layers
  Future<bool> sendWidgetPayload(String payloadJson) async {
    try {
      final bool success = await _channel.invokeMethod<bool>(
        'updateWidgetData',
        {'payloadJson': payloadJson},
      ) ?? false;
      return success;
    } on MissingPluginException {
      debugPrint('ℹ️ NativeWidgetService: Widget platform channel not yet attached (normal during tests).');
      return false;
    } catch (e) {
      debugPrint('❌ NativeWidgetService.sendWidgetPayload error: $e');
      return false;
    }
  }

  /// Build canonical JSON payload from Module 10 data and send to native platforms
  Future<bool> updateWidgetData({
    required List<EkadashiDate> ekadashiList,
    required String timezone,
    required String locationName,
    required LanguageService languageService,
    String tradition = 'General',
  }) async {
    try {
      if (ekadashiList.isEmpty) {
        debugPrint('⚠️ NativeWidgetService: Ekadashi list is empty, skipping widget update.');
        return false;
      }

      final nowUtc = DateTime.now().toUtc();
      final localeCode = languageService.currentLocale.languageCode;

      // 1. Identify currently active or next upcoming Ekadashi
      EkadashiDate? activeOrNextEkadashi;
      final List<EkadashiDate> futureEkadashis = [];

      for (var ekadashi in ekadashiList) {
        // Parse UTC fasting and parana boundaries
        DateTime? pEndUtc;
        if (ekadashi.paranaEndIso.isNotEmpty) {
          pEndUtc = DateTime.tryParse(ekadashi.paranaEndIso)?.toUtc();
        }

        // If parana window is not ended yet, or it's today/future date
        if (pEndUtc != null && nowUtc.isBefore(pEndUtc)) {
          activeOrNextEkadashi ??= ekadashi;
        } else if (pEndUtc == null) {
          final eDate = DateTime.utc(ekadashi.date.year, ekadashi.date.month, ekadashi.date.day, 23, 59, 59);
          if (nowUtc.isBefore(eDate)) {
            activeOrNextEkadashi ??= ekadashi;
          }
        }

        // Collect future ones
        if (activeOrNextEkadashi != null && ekadashi.id != activeOrNextEkadashi.id) {
          futureEkadashis.add(ekadashi);
        }
      }

      // Fallback to first in list if all ended (e.g. end of year)
      activeOrNextEkadashi ??= ekadashiList.first;

      // 2. Evaluate current machine-readable state
      final currentState = _computeState(activeOrNextEkadashi, nowUtc);

      // 3. Build canonical JSON structures
      final Map<String, dynamic> metadata = {
        'schemaVersion': 2,
        'dataVersion': '2.0.0',
        'generatedAtUTC': nowUtc.toIso8601String(),
        'lastUpdatedAtUTC': nowUtc.toIso8601String(),
        'locale': localeCode,
        'timezone': timezone,
        'locationName': locationName,
        'calculationVersion': 'v10.1',
        'tradition': tradition,
      };

      final Map<String, dynamic> nextEkadashiJson = _mapEkadashiItem(
        activeOrNextEkadashi,
        languageService,
      );

      // Take next 10 upcoming for scrollable/responsive widget access
      final List<Map<String, dynamic>> upcomingJson = futureEkadashis
          .take(10)
          .map((e) => _mapEkadashiItem(e, languageService))
          .toList();

      // Bundle localized strings needed by the widget UI
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

      final Map<String, dynamic> payload = {
        'metadata': metadata,
        'currentState': currentState,
        'nextEkadashi': nextEkadashiJson,
        'upcomingEkadashis': upcomingJson,
        'localizedStrings': localizedStrings,
      };

      // 4. Dispatch to Native via MethodChannel
      final bool success = await _channel.invokeMethod<bool>(
        'updateWidgetData',
        {'payloadJson': jsonEncode(payload)},
      ) ?? false;

      debugPrint('✅ NativeWidgetService: Widget data synchronized. Success=$success');
      return success;
    } on MissingPluginException {
      debugPrint('ℹ️ NativeWidgetService: Widget platform channel not yet attached (normal during tests).');
      return false;
    } catch (e) {
      debugPrint('❌ NativeWidgetService error: $e');
      return false;
    }
  }

  /// Request a native widget timeline / glance refresh
  Future<void> forceWidgetRefresh() async {
    try {
      await _channel.invokeMethod('forceWidgetRefresh');
    } catch (e) {
      debugPrint('⚠️ NativeWidgetService.forceWidgetRefresh error: $e');
    }
  }


  // --- Helpers ---

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

  Map<String, dynamic> _mapEkadashiItem(
    EkadashiDate e,
    LanguageService lang,
  ) {
    // Format localized date, e.g. "12 Jan 2026"
    final dateStr = DateFormat('yyyy-MM-dd').format(e.date);
    String localizedDate;
    try {
      localizedDate = DateFormat('d MMM yyyy', lang.currentLocale.languageCode).format(e.date);
    } catch (_) {
      localizedDate = DateFormat('d MMM yyyy').format(e.date);
    }

    final fStartUtc = DateTime.tryParse(e.fastingStartIso)?.toUtc().toIso8601String() ?? e.fastingStartIso;
    final pStartUtc = DateTime.tryParse(e.paranaStartIso)?.toUtc().toIso8601String() ?? e.paranaStartIso;
    final pEndUtc = DateTime.tryParse(e.paranaEndIso)?.toUtc().toIso8601String() ?? e.paranaEndIso;

    return {
      'id': e.id,
      'name': e.name,
      'localizedName': e.name,
      'date': dateStr,
      'localizedDate': localizedDate,
      'paksha': e.paksha,
      'month': e.month,
      'fastingStartUTC': fStartUtc,
      'fastingEndUTC': pStartUtc, // Fasting ends when Parana begins
      'paranaStartUTC': pStartUtc,
      'paranaEndUTC': pEndUtc,
      'targetTimestampUTC': fStartUtc,
      'countdownTarget': fStartUtc,
      'description': e.description,
    };
  }
}
