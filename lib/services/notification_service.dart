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
    } catch (e) {
      debugPrint('Error setting location: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // ANDROID ICON SETUP:
    // Small Icon: White Silhouette (@drawable/notification_icon)
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
        debugPrint('Notification clicked: ${response.payload}');
      },
    );
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
    } else if (Platform.isAndroid) {
      final fln.AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'ekadashi_reminder_channel_v5', // V5: Fresh channel
            'Ekadashi Reminders',
            channelDescription: 'Notifications for upcoming Ekadashi fasts',

            importance: fln.Importance.max,
            priority: fln.Priority.max,
            category: fln.AndroidNotificationCategory.reminder,
            visibility: fln.NotificationVisibility.public,

            playSound: true,
            enableVibration: true,

            // SMALL ICON (Status Bar - Silhouette)
            icon: '@drawable/notification_icon',
            color: Color(0xFF00A19B),

            // LARGE ICON (Notification Body - Full Color)
            // Points to the file you manually copied to android/app/src/main/res/drawable/app_icon.png
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
    } catch (e) {
      debugPrint("CRITICAL ERROR SCHEDULING: $e");
    }
  }

  Future<void> scheduleAllNotifications(
      List<EkadashiDate> dates,
      bool remind1Day,
      bool remind2Days,
      bool remindOnDay,
      Map<String, String> texts) async {

    await cancelAll();

    if (!remind1Day && !remind2Days && !remindOnDay) return;

    int id = 1;
    final now = tz.TZDateTime.now(tz.local);

    for (var ekadashi in dates) {
      final ekadashiDate = ekadashi.date;
      if (ekadashiDate.add(const Duration(days: 1)).isBefore(DateTime.now())) {
        continue;
      }

      if (remind2Days) {
        final scheduledDate = ekadashiDate.subtract(const Duration(days: 2));
        final scheduledDateTime = tz.TZDateTime(
            tz.local, scheduledDate.year, scheduledDate.month, scheduledDate.day, 8, 0);

        if (scheduledDateTime.isAfter(now)) {
          await _scheduleNotification(
            id: id++,
            title: texts['notif_2day_title'] ?? 'Upcoming Ekadashi',
            body: '${ekadashi.name} ${texts['notif_2day_body']}',
            scheduledDate: scheduledDateTime,
          );
        }
      }

      if (remind1Day) {
        final scheduledDate = ekadashiDate.subtract(const Duration(days: 1));
        final scheduledDateTime = tz.TZDateTime(
            tz.local, scheduledDate.year, scheduledDate.month, scheduledDate.day, 8, 0);

        if (scheduledDateTime.isAfter(now)) {
          await _scheduleNotification(
            id: id++,
            title: texts['notif_1day_title'] ?? 'Ekadashi Tomorrow!',
            body: '${ekadashi.name} ${texts['notif_1day_body']} ${ekadashi.fastStartTime}.',
            scheduledDate: scheduledDateTime,
          );
        }
      }

      if (remindOnDay) {
        try {
          final format = DateFormat("hh:mm a");
          final timeParts = format.parse(ekadashi.fastStartTime);
          final scheduledDateTime = tz.TZDateTime(
              tz.local, ekadashiDate.year, ekadashiDate.month, ekadashiDate.day, timeParts.hour, timeParts.minute);

          if (scheduledDateTime.isAfter(now)) {
            await _scheduleNotification(
              id: id++,
              title: texts['notif_start_title'] ?? 'Ekadashi Starts Now',
              body: '${texts['notif_start_body']} ${ekadashi.name}. ${texts['notif_start_suffix']}',
              scheduledDate: scheduledDateTime,
            );
          }
        } catch (e) { debugPrint("Error parsing time: $e"); }
      }
    }
  }

  Future<void> showInstantNotification(String title, String body) async {
    const fln.AndroidNotificationDetails androidNotificationDetails =
    fln.AndroidNotificationDetails(
      'ekadashi_instant_channel',
      'Instant Alerts',
      importance: fln.Importance.max,
      priority: fln.Priority.high,

      // ICONS
      icon: '@drawable/notification_icon',
      color: Color(0xFF00A19B),
      // LARGE ICON
      largeIcon: fln.DrawableResourceAndroidBitmap('@drawable/app_icon'),
    );

    await flutterLocalNotificationsPlugin.show(
      0, title, body,
      const fln.NotificationDetails(
          android: androidNotificationDetails,
          iOS: fln.DarwinNotificationDetails()
      ),
    );
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}