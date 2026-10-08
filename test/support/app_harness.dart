import 'memory_calendar_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

/// Stateful fake of the Android bridge. Tests assert observable outcomes and
/// outgoing requests; they do not claim to run Android scheduling or GPS.
class AppHarness {
  bool locationGranted = true;
  bool notificationGranted = true;
  bool gpsAvailable = true;
  String city = 'Chennai';
  String timezone = 'IST';
  String deviceTimezone = 'Asia/Kolkata';
  bool notificationsEnabled = true;
  bool remind2Days = true;
  bool remind1Day = true;
  bool remindStart = true;
  bool remindParana = true;
  final List<MethodCall> notificationCalls = [];
  final List<MethodCall> widgetCalls = [];
  final List<MethodCall> settingsCalls = [];
  final List<MethodCall> locationCalls = [];

  static const channels = [
    'com.ekadashi.widget',
    'com.ekadashi.settings',
    'com.ekadashi.location',
    'com.ekadashi.notifications',
    'com.ekadashi.permissions',
    'flutter_timezone',
    'dexterous.com/flutter/local_notifications',
  ];

  Future<void> install({Map<String, Object> preferences = const {}}) async {
    await EkadashiService().initializeData();
    // Isolates do not run under the widget tests' fake async.
    ObservanceCalendarService.calculateInline = true;
    await initializeDateFormatting();
    tz.initializeTimeZones();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({
      'has_launched': true,
      'app_version': '1.0',
      ...preferences,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ekadashi.widget'),
      (call) async {
        widgetCalls.add(call);
        return call.method == 'getInitialDeepLink' ? null : true;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ekadashi.settings'),
      (call) async {
        settingsCalls.add(call);
        switch (call.method) {
          case 'checkAllPermissions':
            return permissions;
          case 'getAllSettings':
            return {
              'permissions': permissions,
              'notifications': notificationPreferences,
              'location': {'autoDetect': true, 'timezone': timezone},
              'darkMode': true,
              'languageCode': 'en',
            };
          case 'getNotificationSettings':
            return notificationPreferences;
          case 'updateNotificationSettings':
            final map = Map<String, dynamic>.from(
              (call.arguments as Map)['settings'] as Map,
            );
            notificationsEnabled = map['enabled'] as bool;
            remind2Days = map['remind2Days'] as bool;
            remind1Day = map['remind1Day'] as bool;
            remindStart = map['remindOnStart'] as bool;
            remindParana = map['remindOnParana'] as bool;
            return true;
          case 'getLocationSettings':
            return {'autoDetect': true, 'timezone': timezone};
          default:
            return true;
        }
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ekadashi.location'),
      (call) async {
        locationCalls.add(call);
        switch (call.method) {
          case 'getCurrentLocation':
            return locationGranted && gpsAvailable ? location : null;
          case 'getCachedLocation':
            return null;
          case 'hasLocationPermission':
            return locationGranted;
          case 'requestLocationPermission':
            return locationGranted;
          case 'getCurrentTimezone':
            return timezone;
          case 'setTimezone':
            timezone = (call.arguments as Map)['timezone'] as String;
            return null;
          case 'shouldShowRequestRationale':
            return true;
          default:
            return null;
        }
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ekadashi.notifications'),
      (call) async {
        notificationCalls.add(call);
        if (call.method == 'scheduleAllNotifications') return 4;
        if (call.method == 'getPendingCount') return 4;
        return true;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => deviceTimezone,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => true,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ekadashi.permissions'),
      (_) async => true,
    );
  }

  Map<String, Object> get permissions => {
    'hasNotificationPermission': notificationGranted,
    'hasLocationPermission': locationGranted,
    'hasExactAlarmPermission': true,
    'isBatteryOptimizationDisabled': false,
    'androidVersion': 35,
    'requiresExactAlarmPermission': true,
    'requiresNotificationPermission': true,
  };
  Map<String, Object> get notificationPreferences => {
    'enabled': notificationsEnabled,
    'remind2Days': remind2Days,
    'remind1Day': remind1Day,
    'remindOnStart': remindStart,
    'remindOnParana': remindParana,
  };
  Map<String, Object> get location => {
    'success': true,
    'city': city,
    'timezone': timezone,
    'latitude': 13.0827,
    'longitude': 80.2707,
  };

  Widget app() => MyApp(calendarRepository: MemoryCalendarRepository());

  void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    debugDefaultTargetPlatformOverride = null;
  }
}
