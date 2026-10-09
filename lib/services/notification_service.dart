import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'time_zone_data.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import '../services/ekadashi_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  // Native method channel for Android-specific permission handling
  static const MethodChannel _permissionChannel = MethodChannel(
    'com.ekadashi.permissions',
  );

  String _currentTimeZone = 'UTC';

  Future<void> init() async {
    // Bundled IANA database (see time_zone_data.dart), shared with Panchang.
    initializeTimeZoneData();

    try {
      String timeZoneName = await FlutterTimezone.getLocalTimezone();
      final deviceOffset = DateTime.now().timeZoneOffset;

      // Samsung bug workaround
      if (timeZoneName == 'UTC' && deviceOffset.inMinutes != 0) {
        timeZoneName = _findTimezoneByOffset(deviceOffset.inMinutes);
      }

      // Handle Asia/Calcutta -> Asia/Kolkata
      if (timeZoneName == 'Asia/Calcutta') {
        timeZoneName = 'Asia/Kolkata';
      }

      _currentTimeZone = timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Timezone error: $e, using fallback');
      try {
        final fallbackTz = _findTimezoneByOffset(
          DateTime.now().timeZoneOffset.inMinutes,
        );
        _currentTimeZone = fallbackTz;
        tz.setLocalLocation(tz.getLocation(fallbackTz));
      } catch (_) {
        _currentTimeZone = 'UTC';
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    const androidSettings = fln.AndroidInitializationSettings(
      '@drawable/notification_icon',
    );
    const iosSettings = fln.DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(
        const fln.InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );
      debugPrint('✅ Notification service initialized (TZ: $_currentTimeZone)');
    } catch (e) {
      debugPrint(
        '⚠️ Notification service initialization skipped or failed: $e',
      );
    }
  }

  String _findTimezoneByOffset(int offsetMinutes) {
    const offsetMap = {
      0: 'UTC',
      330: 'Asia/Kolkata',
      300: 'Asia/Karachi',
      480: 'Asia/Singapore',
      540: 'Asia/Tokyo',
      -300: 'America/New_York',
      -480: 'America/Los_Angeles',
      60: 'Europe/Paris',
      120: 'Europe/Helsinki',
    };

    if (offsetMap.containsKey(offsetMinutes)) return offsetMap[offsetMinutes]!;

    int closest = 0;
    int minDiff = offsetMinutes.abs();
    for (final offset in offsetMap.keys) {
      final diff = (offset - offsetMinutes).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = offset;
      }
    }
    return offsetMap[closest]!;
  }

  Future<bool> hasNotificationPermission() async {
    if (Platform.isAndroid) {
      final android = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// Check if app has exact alarm permission using native Android code.
  /// Uses AppOpsManager for reliable detection across all devices including Samsung.
  Future<bool> hasExactAlarmPermission() async {
    if (Platform.isAndroid) {
      try {
        // Use native method channel for reliable permission check
        // This uses AppOpsManager which is more reliable than the flutter plugin
        final bool result = await _permissionChannel.invokeMethod(
          'canScheduleExactAlarms',
        );
        debugPrint('🔔 Native hasExactAlarmPermission: $result');
        return result;
      } catch (e) {
        debugPrint('❌ Native alarm permission check failed: $e');
        // Fallback to flutter plugin if native method fails
        try {
          final android = flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                fln.AndroidFlutterLocalNotificationsPlugin
              >();
          final result =
              await android?.canScheduleExactNotifications() ?? false;
          debugPrint('🔔 Fallback hasExactAlarmPermission: $result');
          return result;
        } catch (e2) {
          debugPrint('❌ Fallback also failed: $e2');
          return false;
        }
      }
    }
    return true; // iOS doesn't need this permission
  }

  Future<bool> requestNotificationPermission() async {
    if (Platform.isIOS) {
      final result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            fln.IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final android = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// Opens the system's Alarms & Reminders settings page.
  /// Uses native Android code for reliable cross-device compatibility.
  Future<bool> openExactAlarmSettings() async {
    if (Platform.isAndroid) {
      try {
        // Use native method channel for reliable intent handling
        final bool result = await _permissionChannel.invokeMethod(
          'openAlarmSettings',
        );
        debugPrint('🔔 openAlarmSettings result: $result');
        return result;
      } catch (e) {
        debugPrint('❌ openAlarmSettings error: $e');
        // Fallback: Try the flutter_local_notifications method
        try {
          final android = flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                fln.AndroidFlutterLocalNotificationsPlugin
              >();
          await android?.requestExactAlarmsPermission();
          return true;
        } catch (e2) {
          debugPrint('❌ Fallback also failed: $e2');
          return false;
        }
      }
    }
    return false;
  }

  /// Android notification details with large app icon on the right
  fln.AndroidNotificationDetails _getAndroidNotificationDetails({
    required String channelId,
    required String channelName,
  }) {
    return fln.AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Ekadashi Calendar notifications',
      importance: fln.Importance.max,
      priority: fln.Priority.high,
      // Small icon (status bar)
      icon: '@drawable/notification_icon',
      color: const Color(0xFF00A19B),
      // Large icon - displayed on the right side of notification
      // Using ic_launcher which is the default app icon
      largeIcon: const fln.DrawableResourceAndroidBitmap('@drawable/app_icon'),
      styleInformation: const fln.BigTextStyleInformation(''),
    );
  }

  Future<void> showInstantNotification(String title, String body) async {
    final androidDetails = _getAndroidNotificationDetails(
      channelId: 'ekadashi_instant',
      channelName: 'Instant Alerts',
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      fln.NotificationDetails(
        android: androidDetails,
        iOS: const fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> showTestNotification(Map<String, String> texts) async {
    await showInstantNotification(
      texts['notif_test_title'] ?? 'Hari Om!',
      texts['notif_test_body'] ?? 'Your notifications are working perfectly!',
    );
  }

  Future<void> scheduleAllNotifications(
    List<EkadashiDate> dates,
    bool remind1Day,
    bool remind2Days,
    bool remindOnDay,
    Map<String, String> texts,
  ) async {
    await cancelAll();

    if (!remind1Day && !remind2Days && !remindOnDay) return;

    if (Platform.isAndroid) {
      if (!await hasNotificationPermission() ||
          !await hasExactAlarmPermission())
        return;
    }

    final now = tz.TZDateTime.now(tz.local);
    debugPrint('📧 Scheduling notifications...');

    int id = 1;
    for (var ekadashi in dates) {
      // 2 days before at 8:00 AM
      if (remind2Days) {
        final notifDate = ekadashi.date.subtract(const Duration(days: 2));
        final scheduled = tz.TZDateTime(
          tz.local,
          notifDate.year,
          notifDate.month,
          notifDate.day,
          8,
          0,
        );

        if (scheduled.isAfter(now)) {
          await _scheduleNotification(
            id: id++,
            title: texts['notif_2day_title'] ?? 'Upcoming Ekadashi',
            body:
                '${ekadashi.name} ${texts['notif_2day_body'] ?? 'is in 2 days. Prepare for your fast.'}',
            scheduledDate: scheduled,
          );
        }
      }

      // 1 day before at 8:00 AM
      if (remind1Day) {
        final notifDate = ekadashi.date.subtract(const Duration(days: 1));
        final scheduled = tz.TZDateTime(
          tz.local,
          notifDate.year,
          notifDate.month,
          notifDate.day,
          8,
          0,
        );

        if (scheduled.isAfter(now)) {
          await _scheduleNotification(
            id: id++,
            title: texts['notif_1day_title'] ?? 'Ekadashi Tomorrow!',
            body:
                '${ekadashi.name} ${texts['notif_1day_body'] ?? 'is tomorrow. Fasting starts at'} ${_clock(ekadashi.fastStartTime, texts)}.',
            scheduledDate: scheduled,
          );
        }
      }

      // On the day at fast start time
      if (remindOnDay) {
        try {
          final timeParts = DateFormat("hh:mm a").parse(ekadashi.fastStartTime);
          final scheduled = tz.TZDateTime(
            tz.local,
            ekadashi.date.year,
            ekadashi.date.month,
            ekadashi.date.day,
            timeParts.hour,
            timeParts.minute,
          );

          if (scheduled.isAfter(now)) {
            final bodyPrefix = texts['notif_start_body'] ?? 'Today is';
            final bodySuffix =
                texts['notif_start_suffix'] ?? 'Fasting begins now.';
            await _scheduleNotification(
              id: id++,
              title: texts['notif_start_title'] ?? 'Ekadashi Starts Now',
              body: '$bodyPrefix ${ekadashi.name}. $bodySuffix',
              scheduledDate: scheduled,
            );
          }
        } catch (_) {}
      }
    }

    debugPrint('✅ Scheduled ${id - 1} notifications');
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      final androidDetails = _getAndroidNotificationDetails(
        channelId: 'ekadashi_reminder',
        channelName: 'Ekadashi Reminders',
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        fln.NotificationDetails(
          android: androidDetails,
          iOS: const fln.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            fln.UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Error scheduling #$id: $e');
    }
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('🗑️ All notifications cancelled');
  }

  /// The stored "06:00 AM" with the notification language's AM and PM.
  static String _clock(String time, Map<String, String> texts) =>
      time.replaceAllMapped(
        RegExp(r'\b(AM|PM)\b'),
        (m) => texts[m[1] == 'AM' ? 'panchang_am' : 'panchang_pm'] ?? m[1]!,
      );
}
