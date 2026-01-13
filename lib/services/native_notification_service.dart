import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native notification service using Kotlin WorkManager
/// More reliable than AlarmManager - guarantees notification delivery
class NativeNotificationService {
  static final NativeNotificationService _instance = NativeNotificationService._internal();
  factory NativeNotificationService() => _instance;
  NativeNotificationService._internal();

  static const MethodChannel _channel = MethodChannel('com.ekadashi.notifications');

  /// Schedule notifications for a single Ekadashi
  /// Returns the number of notifications scheduled
  Future<int> scheduleEkadashiNotifications({
    required int ekadashiId,
    required String ekadashiName,
    required String fastingStartTime,
    required String paranaStartTime,
    required Map<String, String> texts,
  }) async {
    try {
      final result = await _channel.invokeMethod<int>('scheduleNotification', {
        'ekadashiId': ekadashiId,
        'ekadashiName': ekadashiName,
        'fastingStartTime': fastingStartTime,
        'paranaStartTime': paranaStartTime,
        'texts': texts,
      });
      return result ?? 0;
    } catch (e) {
      debugPrint('scheduleEkadashiNotifications error: $e');
      return 0;
    }
  }

  /// Schedule notifications for all Ekadashis at once
  /// More efficient than scheduling one by one
  Future<int> scheduleAllNotifications({
    required List<EkadashiNotificationData> ekadashis,
    required Map<String, String> texts,
  }) async {
    try {
      final ekadashiList = ekadashis.map((e) => {
        'id': e.id,
        'name': e.name,
        'fastingStart': e.fastingStartTime,
        'paranaStart': e.paranaStartTime,
      }).toList();

      final result = await _channel.invokeMethod<int>('scheduleAllNotifications', {
        'ekadashis': ekadashiList,
        'texts': texts,
      });

      debugPrint('✅ Scheduled ${result ?? 0} notifications');
      return result ?? 0;
    } catch (e) {
      debugPrint('scheduleAllNotifications error: $e');
      return 0;
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _channel.invokeMethod('cancelAllNotifications');
      debugPrint('🗑️ All notifications cancelled');
    } catch (e) {
      debugPrint('cancelAllNotifications error: $e');
    }
  }

  /// Cancel notifications for a specific Ekadashi
  Future<void> cancelEkadashiNotifications(int ekadashiId) async {
    try {
      await _channel.invokeMethod('cancelEkadashiNotifications', {
        'ekadashiId': ekadashiId,
      });
    } catch (e) {
      debugPrint('cancelEkadashiNotifications error: $e');
    }
  }

  /// Show a test notification immediately
  Future<void> showTestNotification(String title, String body) async {
    try {
      await _channel.invokeMethod('showTestNotification', {
        'title': title,
        'body': body,
      });
      debugPrint('📢 Test notification sent');
    } catch (e) {
      debugPrint('showTestNotification error: $e');
    }
  }

  /// Get count of pending notifications
  Future<int> getPendingNotificationCount() async {
    try {
      return await _channel.invokeMethod<int>('getPendingCount') ?? 0;
    } catch (e) {
      debugPrint('getPendingNotificationCount error: $e');
      return 0;
    }
  }

  /// Get current notification settings
  Future<NotificationSettings> getSettings() async {
    try {
      final result = await _channel.invokeMethod<Map>('getSettings');
      if (result != null) {
        final map = Map<String, dynamic>.from(result);
        return NotificationSettings(
          enabled: map['notifications_enabled'] as bool? ?? true,
          remind2Days: map['remind_2_days'] as bool? ?? true,
          remind1Day: map['remind_1_day'] as bool? ?? true,
          remindOnStart: map['remind_on_start'] as bool? ?? true,
          remindOnParana: map['remind_on_parana'] as bool? ?? false,
        );
      }
    } catch (e) {
      debugPrint('getSettings error: $e');
    }
    return NotificationSettings();
  }

  /// Update notification settings
  Future<void> updateSettings(NotificationSettings settings) async {
    try {
      await _channel.invokeMethod('updateSettings', {
        'settings': {
          'notifications_enabled': settings.enabled,
          'remind_2_days': settings.remind2Days,
          'remind_1_day': settings.remind1Day,
          'remind_on_start': settings.remindOnStart,
          'remind_on_parana': settings.remindOnParana,
        },
      });
    } catch (e) {
      debugPrint('updateSettings error: $e');
    }
  }

  /// Check if notifications are enabled
  Future<bool> isNotificationsEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationsEnabled') ?? true;
    } catch (e) {
      debugPrint('isNotificationsEnabled error: $e');
      return true;
    }
  }

  /// Set notifications enabled state
  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setNotificationsEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('setNotificationsEnabled error: $e');
    }
  }
}

/// Notification settings model
class NotificationSettings {
  final bool enabled;
  final bool remind2Days;
  final bool remind1Day;
  final bool remindOnStart;
  final bool remindOnParana;

  NotificationSettings({
    this.enabled = true,
    this.remind2Days = true,
    this.remind1Day = true,
    this.remindOnStart = true,
    this.remindOnParana = false,
  });

  int get enabledCount {
    int count = 0;
    if (remind2Days) count++;
    if (remind1Day) count++;
    if (remindOnStart) count++;
    if (remindOnParana) count++;
    return count;
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? remind2Days,
    bool? remind1Day,
    bool? remindOnStart,
    bool? remindOnParana,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      remind2Days: remind2Days ?? this.remind2Days,
      remind1Day: remind1Day ?? this.remind1Day,
      remindOnStart: remindOnStart ?? this.remindOnStart,
      remindOnParana: remindOnParana ?? this.remindOnParana,
    );
  }
}

/// Data class for scheduling Ekadashi notifications
class EkadashiNotificationData {
  final int id;
  final String name;
  final String fastingStartTime;
  final String paranaStartTime;

  EkadashiNotificationData({
    required this.id,
    required this.name,
    required this.fastingStartTime,
    required this.paranaStartTime,
  });
}