import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/data/latest.dart' as tz;
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

  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('✅ Timezone set to: $timeZoneName');
    } catch (e) {
      debugPrint('⚠️ Error setting location: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
    fln.AndroidInitializationSettings('@drawable/notification_icon');

    const fln.DarwinInitializationSettings initializationSettingsDarwin =
    fln.DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const fln.InitializationSettings initializationSettings =
    fln.InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (fln.NotificationResponse response) {
        debugPrint('🔔 Notification clicked: ${response.payload}');
      },
    );

    debugPrint('✅ Notification service initialized');
  }

  Future<bool> hasExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? canSchedule = await androidImplementation.canScheduleExactNotifications();
        return canSchedule ?? false;
      }
    }
    return true;
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          fln.IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('✅ iOS notification permissions requested');
    } else if (Platform.isAndroid) {
      final fln.AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      final bool? exactAlarmGranted = await androidImplementation?.requestExactAlarmsPermission();
      debugPrint('✅ Android notification permissions requested');
      debugPrint('📱 Exact alarms granted: ${exactAlarmGranted ?? false}');
    }
  }

  // DEBUG: Schedule notification exactly 1 minute from NOW
  Future<bool> scheduleDebugNotificationIn1Minute() async {
    try {
      if (Platform.isAndroid && !await hasExactAlarmPermission()) {
        debugPrint('❌ Cannot schedule - exact alarm permission not granted');
        return false;
      }

      final now = tz.TZDateTime.now(tz.local);
      final scheduledTime = now.add(const Duration(minutes: 1));

      final formatter = DateFormat('hh:mm:ss a');
      debugPrint('🧪 DEBUG: Scheduling test notification');
      debugPrint('   Current time: ${formatter.format(now)}');
      debugPrint('   Scheduled for: ${formatter.format(scheduledTime)}');
      debugPrint('   Time difference: 60 seconds');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        999, // Special ID for debug notification
        '⚡ DEBUG Test Successful!',
        'This notification was scheduled exactly 1 minute ago at ${formatter.format(now)}',
        scheduledTime,
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'ekadashi_debug_channel',
            'Debug Notifications',
            channelDescription: 'Test notifications for debugging',
            importance: fln.Importance.max,
            priority: fln.Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@drawable/notification_icon',
            color: Color(0xFFFF9800), // Orange for debug
            largeIcon: fln.DrawableResourceAndroidBitmap('@drawable/app_icon'),
          ),
          iOS: fln.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        fln.UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: fln.DateTimeComponents.dateAndTime,
      );

      debugPrint('✅ DEBUG notification scheduled successfully');
      return true;

    } catch (e) {
      debugPrint('❌ DEBUG notification error: $e');
      return false;
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      if (Platform.isAndroid && !await hasExactAlarmPermission()) {
        debugPrint('⚠️ Cannot schedule notification #$id - exact alarm permission not granted');
        return;
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'ekadashi_reminder_channel_v7',
            'Ekadashi Reminders',
            channelDescription: 'Notifications for upcoming Ekadashi fasts',
            importance: fln.Importance.max,
            priority: fln.Priority.max,
            category: fln.AndroidNotificationCategory.reminder,
            visibility: fln.NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
            icon: '@drawable/notification_icon',
            color: Color(0xFF00A19B),
            largeIcon: fln.DrawableResourceAndroidBitmap('@drawable/app_icon'),
          ),
          iOS: fln.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: fln.InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        fln.UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: fln.DateTimeComponents.dateAndTime,
      );

      final formatter = DateFormat('MMM dd, yyyy hh:mm a');
      final nowFormatted = DateFormat('MMM dd hh:mm a').format(DateTime.now());
      debugPrint('✅ Scheduled #$id: "$title" at ${formatter.format(scheduledDate)} (now: $nowFormatted)');

    } catch (e) {
      debugPrint("❌ ERROR scheduling notification #$id: $e");
    }
  }

  Future<void> scheduleAllNotifications(
      List<EkadashiDate> dates,
      bool remind1Day,
      bool remind2Days,
      bool remindOnDay,
      Map<String, String> texts) async {

    await cancelAll();
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('🔧 Scheduling with: 2-day=$remind2Days, 1-day=$remind1Day, on-day=$remindOnDay');
    debugPrint('🕐 Current time: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}');

    if (!remind1Day && !remind2Days && !remindOnDay) {
      debugPrint('⚠️ All toggles OFF - no notifications scheduled');
      return;
    }

    if (Platform.isAndroid && !await hasExactAlarmPermission()) {
      debugPrint('❌ Exact alarm permission NOT granted!');
      return;
    }

    int id = 1;
    final now = tz.TZDateTime.now(tz.local);
    int scheduled2Day = 0, scheduled1Day = 0, scheduledOnDay = 0;

    for (var ekadashi in dates) {
      final ekadashiDate = ekadashi.date;

      // 2 DAYS BEFORE
      if (remind2Days) {
        final notifDate = ekadashiDate.subtract(const Duration(days: 2));
        final scheduledDateTime = tz.TZDateTime(
            tz.local, notifDate.year, notifDate.month, notifDate.day, 8, 0);

        if (scheduledDateTime.isAfter(now)) {
          await _scheduleNotification(
            id: id++,
            title: texts['notif_2day_title'] ?? 'Upcoming Ekadashi',
            body: '${ekadashi.name} ${texts['notif_2day_body']}',
            scheduledDate: scheduledDateTime,
          );
          scheduled2Day++;
        } else {
          debugPrint('⏭️ Skipped 2-day for ${ekadashi.name}: notification time ${DateFormat('MMM dd hh:mm a').format(scheduledDateTime)} has passed');
        }
      }

      // 1 DAY BEFORE
      if (remind1Day) {
        final notifDate = ekadashiDate.subtract(const Duration(days: 1));
        final scheduledDateTime = tz.TZDateTime(
            tz.local, notifDate.year, notifDate.month, notifDate.day, 8, 0);

        if (scheduledDateTime.isAfter(now)) {
          await _scheduleNotification(
            id: id++,
            title: texts['notif_1day_title'] ?? 'Ekadashi Tomorrow!',
            body: '${ekadashi.name} ${texts['notif_1day_body']} ${ekadashi.fastStartTime}.',
            scheduledDate: scheduledDateTime,
          );
          scheduled1Day++;
        } else {
          debugPrint('⏭️ Skipped 1-day for ${ekadashi.name}: notification time ${DateFormat('MMM dd hh:mm a').format(scheduledDateTime)} has passed');
        }
      }

      // ON THE DAY
      if (remindOnDay) {
        try {
          final format = DateFormat("hh:mm a");
          final timeParts = format.parse(ekadashi.fastStartTime);
          final scheduledDateTime = tz.TZDateTime(
              tz.local, ekadashiDate.year, ekadashiDate.month, ekadashiDate.day,
              timeParts.hour, timeParts.minute);

          if (scheduledDateTime.isAfter(now)) {
            await _scheduleNotification(
              id: id++,
              title: texts['notif_start_title'] ?? 'Ekadashi Starts Now',
              body: '${texts['notif_start_body']} ${ekadashi.name}. ${texts['notif_start_suffix']}',
              scheduledDate: scheduledDateTime,
            );
            scheduledOnDay++;
          } else {
            debugPrint('⏭️ Skipped on-day for ${ekadashi.name}: notification time ${DateFormat('MMM dd hh:mm a').format(scheduledDateTime)} has passed');
          }
        } catch (e) {
          debugPrint("⚠️ Error parsing time for ${ekadashi.name}: $e");
        }
      }
    }

    debugPrint('✅ Scheduled: $scheduled2Day (2-day) + $scheduled1Day (1-day) + $scheduledOnDay (on-day) = ${scheduled2Day + scheduled1Day + scheduledOnDay} total');

    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();

      final pendingNotifications = await androidImplementation?.pendingNotificationRequests() ?? [];
      debugPrint('📊 Android reports ${pendingNotifications.length} pending notifications');
    }
  }

  Future<void> showInstantNotification(String title, String body) async {
    const fln.AndroidNotificationDetails androidNotificationDetails =
    fln.AndroidNotificationDetails(
      'ekadashi_instant_channel',
      'Instant Alerts',
      importance: fln.Importance.max,
      priority: fln.Priority.high,
      icon: '@drawable/notification_icon',
      color: Color(0xFF00A19B),
      largeIcon: fln.DrawableResourceAndroidBitmap('@drawable/app_icon'),
    );

    await flutterLocalNotificationsPlugin.show(
      0, title, body,
      const fln.NotificationDetails(
          android: androidNotificationDetails,
          iOS: fln.DarwinNotificationDetails()
      ),
    );

    debugPrint('🔔 Instant notification sent: "$title"');
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('🗑️ ALL notifications cancelled');
  }
}