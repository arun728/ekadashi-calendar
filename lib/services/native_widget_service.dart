import 'widget_sync_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
            debugPrint(
              '📲 NativeWidgetService received deep link from native: $parsed',
            );
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
      final initialUriStr = await _channel.invokeMethod<String>(
        'getInitialDeepLink',
      );
      if (initialUriStr != null && initialUriStr.isNotEmpty) {
        debugPrint(
          '🚀 NativeWidgetService initial cold-start deep link: $initialUriStr',
        );
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
      final bool success =
          await _channel.invokeMethod<bool>('updateWidgetData', {
            'payloadJson': payloadJson,
          }) ??
          false;
      return success;
    } on MissingPluginException {
      debugPrint(
        'ℹ️ NativeWidgetService: Widget platform channel not yet attached (normal during tests).',
      );
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
  }) => WidgetSyncManager().syncWidgetData(
    ekadashiList: ekadashiList,
    timezone: timezone,
    locationName: locationName,
    languageService: languageService,
    tradition: tradition,
  );
  Future<void> forceWidgetRefresh() async {
    try {
      await _channel.invokeMethod('forceWidgetRefresh');
    } catch (e) {
      debugPrint('Widget refresh failed: $e');
    }
  }

  void clearDeepLinkListener() {
    _deepLinkListener = null;
    _channel.setMethodCallHandler(null);
  }
}
