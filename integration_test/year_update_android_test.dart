import 'dart:io';

import 'package:ekadashi_calendar/main.dart';
import 'package:ekadashi_calendar/services/display_clock.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/app_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android Home rolls over inside All Years and flexible update waits for Restart',
    (tester) async {
      final harness = AppHarness()..deviceTimezone = 'America/Los_Angeles';
      await harness.install(
        preferences: {EkadashiSettings.yearKey: 2026, 'language_code': 'en'},
      );
      const channel = MethodChannel('com.ekadashi.app_update');
      final messenger = binding.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'check' => {'state': 'available', 'versionCode': 7},
          'start' || 'complete' => true,
          _ => null,
        };
      });
      var now = DateTime.parse('2026-12-21T10:12:59+05:30');
      DisplayClock.setTestClock(() => now);
      addTearDown(() {
        DisplayClock.setTestClock(null);
        messenger.setMockMethodCallHandler(channel, null);
        harness.uninstall();
      });

      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 170 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(finder, findsWidgets);
      }

      await tester.pumpWidget(harness.app());
      final menu = find.byKey(const Key('home_year_menu'));
      await waitFor(find.byKey(const Key('home_page_indicator')));
      final update = find.text('Update').hitTestable();
      await waitFor(update);
      await tester.tap(update);
      await waitFor(find.text('Downloading update…'));
      await tester.tap(menu);
      final allYears = find
          .widgetWithText(PopupMenuItem<int>, 'All years')
          .hitTestable();
      await waitFor(allYears);
      await tester.tap(allYears);
      await waitFor(find.text('24 / 49'));

      now = DateTime.parse('2026-12-21T10:13:00+05:30');
      (tester.state(find.byType(MainScreen)) as dynamic).refreshLifecycle();
      await waitFor(find.text('25 / 49'));
      expect(find.text('Sun, 3 Jan 2027'), findsWidgets);

      await binding.convertFlutterSurfaceToImage();
      final dir = Directory('${await getDatabasesPath()}/year-update-evidence');
      await dir.create(recursive: true);
      Future<void> capture(String name) async {
        await tester.pump();
        final bytes = await binding.takeScreenshot(name);
        await File('${dir.path}/$name.png').writeAsBytes(bytes);
      }

      await capture('android-january-rollover');
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('state', {'state': 'downloaded', 'versionCode': 7}),
        ),
        (_) {},
      );
      final restart = find.text('Restart to update').hitTestable();
      await waitFor(restart);
      expect(calls, isNot(contains('complete')));
      await capture('android-restart-to-update');
      await tester.tap(restart);
      await tester.pump();
      expect(calls.last, 'complete');
    },
  );
}
