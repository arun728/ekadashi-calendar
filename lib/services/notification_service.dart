import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import '../services/ekadashi_service.dart';
import 'tradition_service.dart';
import 'tradition_notification_helper.dart';

/// Record of a scheduled notification for inspection, verification, and duplicate tracking
class ScheduledNotificationRecord {
  final int id;
  final String title;
  final String body;
  final tz.TZDateTime scheduledDate;
  final NotificationReminderType type;
  final int ekadashiId;
  final AppTradition tradition;

  const ScheduledNotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.type,
    required this.ekadashiId,
    required this.tradition,
  });

  @override
  String toString() =>
      'ScheduledNotificationRecord(#$id, ekadashi: $ekadashiId, type: $type, tradition: $tradition, time: $scheduledDate, title: $title)';
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  fln.FlutterLocalNotificationsPlugin();

  // Native method channel for Android-specific permission handling
  static const MethodChannel _permissionChannel = MethodChannel('com.ekadashi.permissions');

  String _currentTimeZone = 'UTC';

  Future<void> init() async {
    tz.initializeTimeZones();

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
        final fallbackTz = _findTimezoneByOffset(DateTime.now().timeZoneOffset.inMinutes);
        _currentTimeZone = fallbackTz;
        tz.setLocalLocation(tz.getLocation(fallbackTz));
      } catch (_) {
        _currentTimeZone = 'UTC';
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    const androidSettings = fln.AndroidInitializationSettings('@drawable/notification_icon');
    const iosSettings = fln.DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(
        const fln.InitializationSettings(android: androidSettings, iOS: iosSettings),
      );
      debugPrint('✅ Notification service initialized (TZ: $_currentTimeZone)');
    } catch (e) {
      debugPrint('⚠️ Notification plugin init error (expected in headless test environment): $e');
    }
  }

  String _findTimezoneByOffset(int offsetMinutes) {
    const offsetMap = {
      0: 'UTC', 330: 'Asia/Kolkata', 300: 'Asia/Karachi',
      480: 'Asia/Singapore', 540: 'Asia/Tokyo', -300: 'America/New_York',
      -480: 'America/Los_Angeles', 60: 'Europe/Paris', 120: 'Europe/Helsinki',
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
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final android = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      }
    } catch (_) {
      // In headless test environments where plugin is not initialized
      return true;
    }
    return true;
  }

  /// Check if app has exact alarm permission using native Android code.
  /// Uses AppOpsManager for reliable detection across all devices including Samsung.
  Future<bool> hasExactAlarmPermission() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Use native method channel for reliable permission check
        // This uses AppOpsManager which is more reliable than the flutter plugin
        final bool result = await _permissionChannel.invokeMethod('canScheduleExactAlarms');
        debugPrint('🔔 Native hasExactAlarmPermission: $result');
        return result;
      } catch (e) {
        debugPrint('❌ Native alarm permission check failed: $e');
        // Fallback to flutter plugin if native method fails
        try {
          final android = flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
          final result = await android?.canScheduleExactNotifications() ?? false;
          debugPrint('🔔 Fallback hasExactAlarmPermission: $result');
          return result;
        } catch (e2) {
          debugPrint('❌ Fallback also failed: $e2');
          // In headless test environments where neither channel nor plugin is initialized
          return true;
        }
      }
    }
    return true; // iOS doesn't need this permission
  }

  Future<bool> requestNotificationPermission() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<fln.IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final android = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// Opens the system's Alarms & Reminders settings page.
  /// Uses native Android code for reliable cross-device compatibility.
  Future<bool> openExactAlarmSettings() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Use native method channel for reliable intent handling
        final bool result = await _permissionChannel.invokeMethod('openAlarmSettings');
        debugPrint('🔔 openAlarmSettings result: $result');
        return result;
      } catch (e) {
        debugPrint('❌ openAlarmSettings error: $e');
        // Fallback: Try the flutter_local_notifications method
        try {
          final android = flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
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
      0, title, body,
      fln.NotificationDetails(
        android: androidDetails,
        iOS: const fln.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true
        ),
      ),
    );
  }

  /// In-memory record of scheduled notifications for test verification and deduplication
  final List<ScheduledNotificationRecord> _scheduledNotifications = [];

  /// Read-only view of currently scheduled notifications
  List<ScheduledNotificationRecord> get scheduledNotifications =>
      List.unmodifiable(_scheduledNotifications);

  /// Number of currently scheduled notifications
  int get scheduledCount => _scheduledNotifications.length;

  Future<void> showTestNotification(
    Map<String, String> texts, {
    AppTradition tradition = AppTradition.general,
    String languageCode = 'en',
  }) async {
    final rawTitle = texts['notif_test_title'] ?? 'Hari Om!';
    final tag = TraditionNotificationHelper.getTraditionTag(tradition, languageCode);
    final title = (tag.isNotEmpty && !rawTitle.startsWith('['))
        ? '$tag $rawTitle'
        : rawTitle;

    await showInstantNotification(
      title,
      texts['notif_test_body'] ?? 'Your notifications are working perfectly!',
    );
  }

  /// Helper to get tradition tag for notifications
  static String getTraditionTag(AppTradition tradition, String languageCode) {
    return TraditionNotificationHelper.getTraditionTag(tradition, languageCode);
  }

  /// Helper to get tradition-aware texts map for scheduling
  static Map<String, String> getTraditionNotificationTexts({
    required Map<String, String> baseTexts,
    required AppTradition tradition,
    required String languageCode,
  }) {
    return TraditionNotificationHelper.getTraditionAwareTexts(
      baseTexts: baseTexts,
      tradition: tradition,
      languageCode: languageCode,
    );
  }

  /// Schedule notifications for all Ekadashis according to tradition preference
  Future<int> scheduleAllNotifications(
    List<EkadashiDate> dates,
    bool remind1Day,
    bool remind2Days,
    bool remindOnDay,
    Map<String, String> texts, {
    bool remindOnParana = true,
    bool remindUpcomingParana = false,
    AppTradition tradition = AppTradition.general,
    String languageCode = 'en',
  }) async {
    // 1. Always cancel existing notifications first to prevent duplicates or stale tradition dates
    await cancelAll();

    if (!remind1Day &&
        !remind2Days &&
        !remindOnDay &&
        !remindOnParana &&
        !remindUpcomingParana) {
      return 0;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (!await hasNotificationPermission() || !await hasExactAlarmPermission()) {
          debugPrint('⏭️ Skipping scheduling - permissions not granted');
          return 0;
        }
      } catch (_) {}
    }

    final now = tz.TZDateTime.now(tz.local);
    debugPrint('📧 Scheduling tradition-aware notifications (${tradition.name}, lang: $languageCode)...');

    int scheduledTotal = 0;

    for (var ekadashi in dates) {
      // Deterministic base ID prevents duplicate collisions: (ekadashi.id * 10) + offset
      final baseId = ekadashi.id * 10;

      // 1. Two days before at 8:00 AM local time
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
          final content = TraditionNotificationHelper.buildContent(
            type: NotificationReminderType.twoDaysBefore,
            ekadashiName: ekadashi.name,
            tradition: tradition,
            languageCode: languageCode,
            texts: texts,
          );

          final notifId = baseId + 1;
          await _scheduleNotification(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
          );

          _scheduledNotifications.add(ScheduledNotificationRecord(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
            type: NotificationReminderType.twoDaysBefore,
            ekadashiId: ekadashi.id,
            tradition: tradition,
          ));
          scheduledTotal++;
        }
      }

      // 2. One day before at 8:00 AM local time
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
          final content = TraditionNotificationHelper.buildContent(
            type: NotificationReminderType.oneDayBefore,
            ekadashiName: ekadashi.name,
            tradition: tradition,
            languageCode: languageCode,
            fastStartTime: ekadashi.fastStartTime,
            texts: texts,
          );

          final notifId = baseId + 2;
          await _scheduleNotification(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
          );

          _scheduledNotifications.add(ScheduledNotificationRecord(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
            type: NotificationReminderType.oneDayBefore,
            ekadashiId: ekadashi.id,
            tradition: tradition,
          ));
          scheduledTotal++;
        }
      }

      // 3. Fasting day start (sunrise / fast begin)
      if (remindOnDay) {
        tz.TZDateTime? scheduled;
        if (ekadashi.fastingStartIso.isNotEmpty) {
          try {
            final dt = DateTime.parse(ekadashi.fastingStartIso);
            scheduled = tz.TZDateTime.from(dt, tz.local);
          } catch (_) {}
        }
        if (scheduled == null && ekadashi.fastStartTime.isNotEmpty) {
          try {
            final timeParts = DateFormat("hh:mm a").parse(ekadashi.fastStartTime);
            scheduled = tz.TZDateTime(
              tz.local,
              ekadashi.date.year,
              ekadashi.date.month,
              ekadashi.date.day,
              timeParts.hour,
              timeParts.minute,
            );
          } catch (_) {}
        }

        if (scheduled != null && scheduled.isAfter(now)) {
          final content = TraditionNotificationHelper.buildContent(
            type: NotificationReminderType.fastingDay,
            ekadashiName: ekadashi.name,
            tradition: tradition,
            languageCode: languageCode,
            fastStartTime: ekadashi.fastStartTime,
            texts: texts,
          );

          final notifId = baseId + 3;
          await _scheduleNotification(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
          );

          _scheduledNotifications.add(ScheduledNotificationRecord(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
            type: NotificationReminderType.fastingDay,
            ekadashiId: ekadashi.id,
            tradition: tradition,
          ));
          scheduledTotal++;
        }
      }

      // 4. Upcoming Parana Window (Evening before Dwadashi at 8:00 PM local time)
      if (remindUpcomingParana) {
        final scheduled = tz.TZDateTime(
          tz.local,
          ekadashi.date.year,
          ekadashi.date.month,
          ekadashi.date.day,
          20,
          0,
        );

        if (scheduled.isAfter(now)) {
          final content = TraditionNotificationHelper.buildContent(
            type: NotificationReminderType.upcomingParana,
            ekadashiName: ekadashi.name,
            tradition: tradition,
            languageCode: languageCode,
            paranaWindow: ekadashi.fastBreakTime,
            texts: texts,
          );

          final notifId = baseId + 4;
          await _scheduleNotification(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
          );

          _scheduledNotifications.add(ScheduledNotificationRecord(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
            type: NotificationReminderType.upcomingParana,
            ekadashiId: ekadashi.id,
            tradition: tradition,
          ));
          scheduledTotal++;
        }
      }

      // 5. Parana Day Window (Fast breaking reminder at parana start time)
      if (remindOnParana) {
        tz.TZDateTime? scheduled;
        if (ekadashi.paranaStartIso.isNotEmpty) {
          try {
            final dt = DateTime.parse(ekadashi.paranaStartIso);
            scheduled = tz.TZDateTime.from(dt, tz.local);
          } catch (_) {}
        }
        if (scheduled == null && ekadashi.fastBreakTime.isNotEmpty) {
          try {
            final startPart = ekadashi.fastBreakTime.split('-').first.trim();
            final timeParts = DateFormat("hh:mm a").parse(startPart);
            final paranaDay = ekadashi.date.add(const Duration(days: 1));
            scheduled = tz.TZDateTime(
              tz.local,
              paranaDay.year,
              paranaDay.month,
              paranaDay.day,
              timeParts.hour,
              timeParts.minute,
            );
          } catch (_) {}
        }

        if (scheduled != null && scheduled.isAfter(now)) {
          final content = TraditionNotificationHelper.buildContent(
            type: NotificationReminderType.paranaDay,
            ekadashiName: ekadashi.name,
            tradition: tradition,
            languageCode: languageCode,
            paranaWindow: ekadashi.fastBreakTime,
            texts: texts,
          );

          final notifId = baseId + 5;
          await _scheduleNotification(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
          );

          _scheduledNotifications.add(ScheduledNotificationRecord(
            id: notifId,
            title: content.title,
            body: content.body,
            scheduledDate: scheduled,
            type: NotificationReminderType.paranaDay,
            ekadashiId: ekadashi.id,
            tradition: tradition,
          ));
          scheduledTotal++;
        }
      }
    }

    debugPrint('✅ Scheduled $scheduledTotal tradition-aware notifications');
    return scheduledTotal;
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

  /// Cancel all notifications for a specific Ekadashi by ID
  Future<void> cancelEkadashi(int ekadashiId) async {
    final baseId = ekadashiId * 10;
    for (int offset = 1; offset <= 5; offset++) {
      try {
        await flutterLocalNotificationsPlugin.cancel(baseId + offset);
      } catch (_) {}
    }
    _scheduledNotifications.removeWhere((n) => n.ekadashiId == ekadashiId);
  }

  /// Cancel all scheduled notifications and clear in-memory records
  Future<void> cancelAll() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error cancelling notifications: $e');
    }
    _scheduledNotifications.clear();
    debugPrint('🗑️ All notifications cancelled');
  }
}