import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/native_notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The Android notification channel (system Settings > Notifications) is
/// named in the app language, like every other word the app shows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, String> texts(String language) => {
    for (final key in [
      'notifications',
      'notifications_section_ekadashi',
      'notifications_section_events',
    ])
      key: AppStrings.translate(key, language),
  };

  test('the channel name and description come from existing keys', () {
    for (final language in ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
      final labels = NativeNotificationService.channelLabels(texts(language));
      expect(labels.name, AppStrings.translate('notifications', language));
      expect(
        labels.description,
        '${AppStrings.translate('notifications_section_ekadashi', language)}, '
        '${AppStrings.translate('notifications_section_events', language)}',
      );
      if (language != 'en') {
        expect(labels.name, isNot(contains(RegExp('[A-Za-z]'))));
        expect(labels.description, isNot(contains(RegExp('[A-Za-z]'))));
      }
    }
  });

  test('localizeChannel sends the labels to the native scheduler', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ekadashi.notifications'),
          (call) async {
            calls.add(call);
            return true;
          },
        );
    await NativeNotificationService().localizeChannel(texts('hi'));
    expect(calls.single.method, 'localizeChannel');
    expect(calls.single.arguments, {
      'name': AppStrings.translate('notifications', 'hi'),
      'description':
          '${AppStrings.translate('notifications_section_ekadashi', 'hi')}, '
          '${AppStrings.translate('notifications_section_events', 'hi')}',
    });
  });

  for (final enabled in [true, false]) {
    testWidgets('the app names the channel in its language '
        '(notifications ${enabled ? 'on' : 'off'})', (tester) async {
      final harness = AppHarness()..notificationsEnabled = enabled;
      await tester.runAsync(
        () => harness.install(preferences: {'language_code': 'ta'}),
      );
      addTearDown(harness.uninstall);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      final calls = harness.notificationCalls.where(
        (c) => c.method == 'localizeChannel',
      );
      expect(calls, isNotEmpty);
      expect(
        (calls.last.arguments as Map)['name'],
        AppStrings.translate('notifications', 'ta'),
      );
    });
  }
}
