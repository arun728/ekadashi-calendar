import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Native Settings Service - communicates with Kotlin SettingsService
/// for permission handling and settings management.
/// 
/// Benefits over Flutter plugins:
/// - Runs on native IO threads (no main thread blocking)
/// - Faster permission checks
/// - No freeze when returning from system settings
/// - Smoother lifecycle handling
class NativeSettingsService {
  static const MethodChannel _channel = MethodChannel('com.ekadashi.settings');

  // Singleton pattern
  static final NativeSettingsService _instance = NativeSettingsService._internal();
  factory NativeSettingsService() => _instance;
  NativeSettingsService._internal();

  // ============================================================
  // PERMISSION CHECKS
  // ============================================================

  /// Check all permissions at once - more efficient than multiple calls.
  /// Returns a PermissionStatus object with all permission states.
  Future<PermissionStatus> checkAllPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('checkAllPermissions')
          .timeout(const Duration(milliseconds: 1500));
      if (result == null) return PermissionStatus.defaults();

      // Convert to proper types
      final map = result.map((k, v) => MapEntry(k.toString(), v));

      return PermissionStatus(
        hasNotificationPermission: map['hasNotificationPermission'] as bool? ?? false,
        hasExactAlarmPermission: map['hasExactAlarmPermission'] as bool? ?? true,
        hasLocationPermission: map['hasLocationPermission'] as bool? ?? false,
        isBatteryOptimizationDisabled: map['isBatteryOptimizationDisabled'] as bool? ?? false,
        androidVersion: map['androidVersion'] as int? ?? 0,
        requiresExactAlarmPermission: map['requiresExactAlarmPermission'] as bool? ?? false,
        requiresNotificationPermission: map['requiresNotificationPermission'] as bool? ?? false,
      );
    } on TimeoutException {
      debugPrint('NativeSettingsService.checkAllPermissions timeout - returning defaults');
      return PermissionStatus.defaults();
    } catch (e) {
      debugPrint('NativeSettingsService.checkAllPermissions error: $e');
      return PermissionStatus.defaults();
    }
  }

  /// Check if notification permission is granted.
  Future<bool> hasNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasNotificationPermission') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.hasNotificationPermission error: $e');
      return false;
    }
  }

  /// Check if exact alarm permission is granted (Android 12+).
  Future<bool> hasExactAlarmPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? true;
    } catch (e) {
      debugPrint('NativeSettingsService.hasExactAlarmPermission error: $e');
      return true; // Default to true on error to not block functionality
    }
  }

  /// Check if location permission is granted.
  Future<bool> hasLocationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasLocationPermission') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.hasLocationPermission error: $e');
      return false;
    }
  }

  /// Check if battery optimization is disabled.
  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.isBatteryOptimizationDisabled error: $e');
      return false;
    }
  }

  // ============================================================
  // OPEN SETTINGS INTENTS
  // ============================================================

  /// Open app notification settings.
  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.openNotificationSettings error: $e');
      return false;
    }
  }

  /// Open exact alarm settings (Android 12+).
  Future<bool> openExactAlarmSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openExactAlarmSettings') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.openExactAlarmSettings error: $e');
      return false;
    }
  }

  /// Open battery optimization settings.
  Future<bool> openBatteryOptimizationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openBatteryOptimizationSettings') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.openBatteryOptimizationSettings error: $e');
      return false;
    }
  }

  /// Open app settings page.
  Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.openAppSettings error: $e');
      return false;
    }
  }

  /// Open location settings.
  Future<bool> openLocationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openLocationSettings') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.openLocationSettings error: $e');
      return false;
    }
  }

  // ============================================================
  // NOTIFICATION SETTINGS
  // ============================================================

  /// Get all notification settings.
  Future<NotificationPrefs> getNotificationSettings() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getNotificationSettings');
      if (result == null) return NotificationPrefs.defaults();

      final map = result.map((k, v) => MapEntry(k.toString(), v));

      return NotificationPrefs(
        enabled: map['enabled'] as bool? ?? true,
        remind2Days: map['remind2Days'] as bool? ?? true,
        remind1Day: map['remind1Day'] as bool? ?? true,
        remindOnStart: map['remindOnStart'] as bool? ?? true,
        remindOnParana: map['remindOnParana'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('NativeSettingsService.getNotificationSettings error: $e');
      return NotificationPrefs.defaults();
    }
  }

  /// Update notification settings.
  Future<bool> updateNotificationSettings(NotificationPrefs settings) async {
    try {
      return await _channel.invokeMethod<bool>('updateNotificationSettings', {
        'settings': {
          'enabled': settings.enabled,
          'remind2Days': settings.remind2Days,
          'remind1Day': settings.remind1Day,
          'remindOnStart': settings.remindOnStart,
          'remindOnParana': settings.remindOnParana,
        },
      }) ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.updateNotificationSettings error: $e');
      return false;
    }
  }

  /// Set individual notification setting.
  Future<bool> setNotificationSetting(String key, bool value) async {
    try {
      return await _channel.invokeMethod<bool>('setNotificationSetting', {
        'key': key,
        'value': value,
      }) ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.setNotificationSetting error: $e');
      return false;
    }
  }

  // ============================================================
  // LOCATION SETTINGS
  // ============================================================

  /// Get location settings.
  Future<LocationSettings> getLocationSettings() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getLocationSettings');
      if (result == null) return LocationSettings.defaults();

      final map = result.map((k, v) => MapEntry(k.toString(), v));

      return LocationSettings(
        autoDetect: map['autoDetect'] as bool? ?? true,
        cityId: map['cityId'] as String?,
        timezone: map['timezone'] as String? ?? 'IST',
      );
    } catch (e) {
      debugPrint('NativeSettingsService.getLocationSettings error: $e');
      return LocationSettings.defaults();
    }
  }

  /// Update location settings.
  Future<bool> updateLocationSettings({
    required bool autoDetect,
    String? cityId,
    required String timezone,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('updateLocationSettings', {
        'autoDetect': autoDetect,
        'cityId': cityId,
        'timezone': timezone,
      }) ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.updateLocationSettings error: $e');
      return false;
    }
  }

  // ============================================================
  // THEME SETTINGS
  // ============================================================

  /// Get dark mode setting.
  Future<bool> isDarkMode() async {
    try {
      return await _channel.invokeMethod<bool>('isDarkMode') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.isDarkMode error: $e');
      return false;
    }
  }

  /// Set dark mode setting.
  Future<bool> setDarkMode(bool enabled) async {
    try {
      return await _channel.invokeMethod<bool>('setDarkMode', {
        'enabled': enabled,
      }) ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.setDarkMode error: $e');
      return false;
    }
  }

  // ============================================================
  // LANGUAGE SETTINGS
  // ============================================================

  /// Get current language code.
  Future<String> getLanguageCode() async {
    try {
      return await _channel.invokeMethod<String>('getLanguageCode') ?? 'en';
    } catch (e) {
      debugPrint('NativeSettingsService.getLanguageCode error: $e');
      return 'en';
    }
  }

  /// Set language code.
  Future<bool> setLanguageCode(String code) async {
    try {
      return await _channel.invokeMethod<bool>('setLanguageCode', {
        'code': code,
      }) ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.setLanguageCode error: $e');
      return false;
    }
  }

  // ============================================================
  // ALL SETTINGS
  // ============================================================

  /// Get all settings at once for initial load.
  Future<AllSettings> getAllSettings() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getAllSettings');
      if (result == null) return AllSettings.defaults();

      return AllSettings.fromMap(result);
    } catch (e) {
      debugPrint('NativeSettingsService.getAllSettings error: $e');
      return AllSettings.defaults();
    }
  }

  /// Reset all settings to defaults.
  Future<bool> resetToDefaults() async {
    try {
      return await _channel.invokeMethod<bool>('resetToDefaults') ?? false;
    } catch (e) {
      debugPrint('NativeSettingsService.resetToDefaults error: $e');
      return false;
    }
  }
}

// ============================================================
// DATA MODELS
// ============================================================

/// Permission status data model.
class PermissionStatus {
  final bool hasNotificationPermission;
  final bool hasExactAlarmPermission;
  final bool hasLocationPermission;
  final bool isBatteryOptimizationDisabled;
  final int androidVersion;
  final bool requiresExactAlarmPermission;
  final bool requiresNotificationPermission;

  PermissionStatus({
    required this.hasNotificationPermission,
    required this.hasExactAlarmPermission,
    required this.hasLocationPermission,
    required this.isBatteryOptimizationDisabled,
    required this.androidVersion,
    required this.requiresExactAlarmPermission,
    required this.requiresNotificationPermission,
  });

  factory PermissionStatus.defaults() => PermissionStatus(
    hasNotificationPermission: false,
    hasExactAlarmPermission: true,
    hasLocationPermission: false,
    isBatteryOptimizationDisabled: false,
    androidVersion: 0,
    requiresExactAlarmPermission: false,
    requiresNotificationPermission: false,
  );

  /// Check if all required permissions are granted.
  bool get allPermissionsGranted =>
      hasNotificationPermission && hasExactAlarmPermission;

  /// Check if any permission is missing.
  bool get hasMissingPermissions =>
      !hasNotificationPermission || !hasExactAlarmPermission;
}

/// Notification preferences data model.
/// Named "NotificationPrefs" to avoid conflict with NotificationSettings in native_notification_service.dart
class NotificationPrefs {
  final bool enabled;
  final bool remind2Days;
  final bool remind1Day;
  final bool remindOnStart;
  final bool remindOnParana;

  NotificationPrefs({
    required this.enabled,
    required this.remind2Days,
    required this.remind1Day,
    required this.remindOnStart,
    required this.remindOnParana,
  });

  factory NotificationPrefs.defaults() => NotificationPrefs(
    enabled: true,
    remind2Days: true,
    remind1Day: true,
    remindOnStart: true,
    remindOnParana: true,
  );

  /// Get count of enabled reminder types.
  int get enabledCount {
    int count = 0;
    if (remind2Days) count++;
    if (remind1Day) count++;
    if (remindOnStart) count++;
    if (remindOnParana) count++;
    return count;
  }

  NotificationPrefs copyWith({
    bool? enabled,
    bool? remind2Days,
    bool? remind1Day,
    bool? remindOnStart,
    bool? remindOnParana,
  }) {
    return NotificationPrefs(
      enabled: enabled ?? this.enabled,
      remind2Days: remind2Days ?? this.remind2Days,
      remind1Day: remind1Day ?? this.remind1Day,
      remindOnStart: remindOnStart ?? this.remindOnStart,
      remindOnParana: remindOnParana ?? this.remindOnParana,
    );
  }
}

/// Location settings data model.
class LocationSettings {
  final bool autoDetect;
  final String? cityId;
  final String timezone;

  LocationSettings({
    required this.autoDetect,
    this.cityId,
    required this.timezone,
  });

  factory LocationSettings.defaults() => LocationSettings(
    autoDetect: true,
    cityId: null,
    timezone: 'IST',
  );

  LocationSettings copyWith({
    bool? autoDetect,
    String? cityId,
    String? timezone,
  }) {
    return LocationSettings(
      autoDetect: autoDetect ?? this.autoDetect,
      cityId: cityId ?? this.cityId,
      timezone: timezone ?? this.timezone,
    );
  }
}

/// All settings combined.
class AllSettings {
  final PermissionStatus permissions;
  final NotificationPrefs notifications;
  final LocationSettings location;
  final bool darkMode;
  final String languageCode;

  AllSettings({
    required this.permissions,
    required this.notifications,
    required this.location,
    required this.darkMode,
    required this.languageCode,
  });

  factory AllSettings.defaults() => AllSettings(
    permissions: PermissionStatus.defaults(),
    notifications: NotificationPrefs.defaults(),
    location: LocationSettings.defaults(),
    darkMode: false,
    languageCode: 'en',
  );

  factory AllSettings.fromMap(Map<Object?, Object?> map) {
    final permMap = map['permissions'] as Map<Object?, Object?>?;
    final notifMap = map['notifications'] as Map<Object?, Object?>?;
    final locMap = map['location'] as Map<Object?, Object?>?;

    return AllSettings(
      permissions: permMap != null ? PermissionStatus(
        hasNotificationPermission: permMap['hasNotificationPermission'] as bool? ?? false,
        hasExactAlarmPermission: permMap['hasExactAlarmPermission'] as bool? ?? true,
        hasLocationPermission: permMap['hasLocationPermission'] as bool? ?? false,
        isBatteryOptimizationDisabled: permMap['isBatteryOptimizationDisabled'] as bool? ?? false,
        androidVersion: permMap['androidVersion'] as int? ?? 0,
        requiresExactAlarmPermission: permMap['requiresExactAlarmPermission'] as bool? ?? false,
        requiresNotificationPermission: permMap['requiresNotificationPermission'] as bool? ?? false,
      ) : PermissionStatus.defaults(),
      notifications: notifMap != null ? NotificationPrefs(
        enabled: notifMap['enabled'] as bool? ?? true,
        remind2Days: notifMap['remind2Days'] as bool? ?? true,
        remind1Day: notifMap['remind1Day'] as bool? ?? true,
        remindOnStart: notifMap['remindOnStart'] as bool? ?? true,
        remindOnParana: notifMap['remindOnParana'] as bool? ?? false,
      ) : NotificationPrefs.defaults(),
      location: locMap != null ? LocationSettings(
        autoDetect: locMap['autoDetect'] as bool? ?? true,
        cityId: locMap['cityId'] as String?,
        timezone: locMap['timezone'] as String? ?? 'IST',
      ) : LocationSettings.defaults(),
      darkMode: map['darkMode'] as bool? ?? false,
      languageCode: map['languageCode'] as String? ?? 'en',
    );
  }
}