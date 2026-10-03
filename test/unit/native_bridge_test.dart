import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/native_location_service.dart';
import 'package:ekadashi_calendar/services/native_notification_service.dart';
import 'package:ekadashi_calendar/services/native_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const locationChannel = MethodChannel('com.ekadashi.location');
  const settingsChannel = MethodChannel('com.ekadashi.settings');
  const notificationsChannel = MethodChannel('com.ekadashi.notifications');
  tearDown(() {
    for (final c in [locationChannel, settingsChannel, notificationsChannel]) {
      messenger.setMockMethodCallHandler(c, null);
    }
  });

  test(
    'Native location result retains coordinates and selected timezone',
    () async {
      messenger.setMockMethodCallHandler(
        locationChannel,
        (call) async => {
          'success': true,
          'latitude': 13,
          'longitude': 80.5,
          'city': 'Chennai',
          'timezone': 'IST',
        },
      );
      final result = await NativeLocationService().getCurrentLocation();
      expect(result?.latitude, 13.0);
      expect(result?.longitude, 80.5);
      expect(result?.city, 'Chennai');
      expect(result?.timezone, 'IST');
      final cached = await NativeLocationService().getCachedLocation();
      expect(cached?.latitude, result?.latitude);
      expect(result.toString(), contains('Chennai'));
    },
  );
  for (final response in [
    null,
    {'success': false, 'errorCode': 'PERMISSION_DENIED'},
    {'success': true, 'latitude': 'invalid', 'longitude': 0},
  ]) {
    test(
      'Unavailable or malformed location does not crash: $response',
      () async {
        messenger.setMockMethodCallHandler(
          locationChannel,
          (_) async => response,
        );
        expect(await NativeLocationService().getCurrentLocation(), isNull);
        expect(await NativeLocationService().getCachedLocation(), isNull);
      },
    );
  }
  test('Location platform failure fails closed for permissions', () async {
    messenger.setMockMethodCallHandler(
      locationChannel,
      (_) async => throw PlatformException(code: 'SERVICE_NOT_READY'),
    );
    final s = NativeLocationService();
    expect(await s.getCurrentLocation(), isNull);
    expect(await s.hasLocationPermission(), isFalse);
    expect(await s.requestLocationPermission(), isFalse);
    expect(await s.isLocationEnabled(), isFalse);
    expect(await s.shouldShowRequestRationale(), isFalse);
  });
  testWidgets(
    'Location permission timeout finishes rather than blocking the UI',
    (tester) async {
      final pending = Completer<Object?>();
      messenger.setMockMethodCallHandler(
        locationChannel,
        (_) => pending.future,
      );
      bool? result;
      final request = NativeLocationService().hasLocationPermission().then(
        (v) => result = v,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1501));
      await request;
      expect(result, isFalse);
      pending.complete(null);
    },
  );
  test(
    'Manual location controls send a nullable city and preserve chosen timezone',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(locationChannel, (call) async {
        calls.add(call);
        if (call.method == 'getSelectedCityId') return 'new_york';
        if (call.method == 'isAutoDetectEnabled') return false;
        if (call.method == 'getCurrentTimezone') return 'EST';
        return null;
      });
      final s = NativeLocationService();
      expect(await s.getSelectedCityId(), 'new_york');
      expect(await s.isAutoDetectEnabled(), isFalse);
      expect(await s.getCurrentTimezone(), 'EST');
      await s.setSelectedCityId(null);
      await s.setAutoDetectEnabled(false);
      await s.setTimezone('EST');
      await s.clearCache();
      expect(
        calls.singleWhere((c) => c.method == 'setSelectedCityId').arguments,
        {'cityId': null},
      );
      expect(calls.singleWhere((c) => c.method == 'setTimezone').arguments, {
        'timezone': 'EST',
      });
    },
  );
  test(
    'Permission and preference snapshot keeps denied notifications distinct from opt-in settings',
    () async {
      messenger.setMockMethodCallHandler(
        settingsChannel,
        (_) async => {
          'permissions': {
            'hasNotificationPermission': false,
            'hasLocationPermission': true,
            'hasExactAlarmPermission': true,
            'androidVersion': 33,
            'requiresNotificationPermission': true,
          },
          'notifications': {
            'enabled': true,
            'remind2Days': false,
            'remind1Day': true,
            'remindOnStart': true,
            'remindOnParana': true,
          },
          'location': {
            'autoDetect': false,
            'cityId': 'new_york',
            'timezone': 'EST',
          },
          'darkMode': true,
          'languageCode': 'ta',
        },
      );
      final result = await NativeSettingsService().getAllSettings();
      expect(result.permissions.hasMissingPermissions, isTrue);
      expect(result.permissions.hasLocationPermission, isTrue);
      expect(result.notifications.enabled, isTrue);
      expect(result.notifications.enabledCount, 3);
      expect(result.location.timezone, 'EST');
      expect(result.location.cityId, 'new_york');
      expect(result.languageCode, 'ta');
    },
  );
  test(
    'Settings writes use the native schema without losing Parana or timezone',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(settingsChannel, (c) async {
        calls.add(c);
        return true;
      });
      final s = NativeSettingsService();
      final prefs = NotificationPrefs.defaults().copyWith(
        remind2Days: false,
        remindOnParana: false,
      );
      expect(await s.updateNotificationSettings(prefs), isTrue);
      expect(
        await s.updateLocationSettings(
          autoDetect: false,
          cityId: 'seattle',
          timezone: 'PST',
        ),
        isTrue,
      );
      await s.setNotificationSetting('remind_on_parana', false);
      await s.setLanguageCode('hi');
      await s.setDarkMode(false);
      expect((calls.first.arguments as Map)['settings'], {
        'enabled': true,
        'remind2Days': false,
        'remind1Day': true,
        'remindOnStart': true,
        'remindOnParana': false,
      });
      expect(calls[1].arguments, {
        'autoDetect': false,
        'cityId': 'seattle',
        'timezone': 'PST',
      });
    },
  );
  test(
    'Missing settings bridge provides safe defaults and reports failed writes',
    () async {
      messenger.setMockMethodCallHandler(
        settingsChannel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      final s = NativeSettingsService();
      final p = await s.checkAllPermissions();
      expect(p.hasNotificationPermission, isFalse);
      expect(p.hasLocationPermission, isFalse);
      expect(
        await s.updateNotificationSettings(NotificationPrefs.defaults()),
        isFalse,
      );
      expect(await s.setLanguageCode('ta'), isFalse);
      expect((await s.getLocationSettings()).timezone, 'IST');
    },
  );
  test(
    'Notification batch carries UTC/offset timestamps and localized notification text',
    () async {
      MethodCall? captured;
      messenger.setMockMethodCallHandler(notificationsChannel, (c) async {
        captured = c;
        return 4;
      });
      const start = '2026-12-01T06:00:00-08:00';
      const parana = '2026-12-02T07:00:00-08:00';
      final result = await NativeNotificationService().scheduleAllNotifications(
        ekadashis: [
          EkadashiNotificationData(
            id: 42,
            name: 'Localized name',
            fastingStartTime: start,
            paranaStartTime: parana,
          ),
        ],
        texts: {'notif_start_title': 'Localized title'},
      );
      expect(result, 4);
      final args = captured!.arguments as Map;
      expect(args['texts'], {'notif_start_title': 'Localized title'});
      expect((args['ekadashis'] as List).single, {
        'id': 42,
        'name': 'Localized name',
        'fastingStart': start,
        'paranaStart': parana,
      });
    },
  );
  test(
    'Single notification and cancellation preserve occurrence identity',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(notificationsChannel, (c) async {
        calls.add(c);
        return c.method == 'scheduleNotification' ? 2 : null;
      });
      final s = NativeNotificationService();
      expect(
        await s.scheduleEkadashiNotifications(
          ekadashiId: 9,
          ekadashiName: 'Review',
          fastingStartTime: '2026-12-01T06:00:00+05:30',
          paranaStartTime: '2026-12-02T06:00:00+05:30',
          texts: {},
        ),
        2,
      );
      await s.cancelEkadashiNotifications(9);
      await s.cancelAllNotifications();
      expect((calls.first.arguments as Map)['ekadashiId'], 9);
      expect(calls[1].arguments, {'ekadashiId': 9});
      expect(calls[2].method, 'cancelAllNotifications');
    },
  );
  test(
    'Scheduler bridge failure returns zero instead of a false success count',
    () async {
      messenger.setMockMethodCallHandler(
        notificationsChannel,
        (_) async => throw PlatformException(code: 'SERVICE_NOT_READY'),
      );
      final s = NativeNotificationService();
      expect(await s.scheduleAllNotifications(ekadashis: [], texts: {}), 0);
      expect(await s.getPendingNotificationCount(), 0);
    },
  );
  test(
    'Notification settings round-trip includes Parana and per-type opt-outs',
    () async {
      Map? saved;
      messenger.setMockMethodCallHandler(notificationsChannel, (c) async {
        if (c.method == 'updateSettings') {
          saved = (c.arguments as Map)['settings'] as Map;
          return null;
        }
        if (c.method == 'getSettings') return saved;
        return true;
      });
      final s = NativeNotificationService();
      await s.updateSettings(
        NotificationSettings().copyWith(
          remind2Days: false,
          remindOnParana: false,
        ),
      );
      final restored = await s.getSettings();
      expect(restored.enabledCount, 2);
      expect(restored.remindOnParana, isFalse);
    },
  );
}
