import 'package:ekadashi_calendar/services/native_settings_service.dart';
import 'package:ekadashi_calendar/services/notification_service.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/services/practice_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/devotion_audio_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/screens/practice_screen.dart';
import '../test/support/premium_fixture.dart';
import '../test/support/devotion_navigation.dart';

/// A synthesized tone is a test signal, never a released devotional recording.
Uint8List testTone() {
  const rate = 16000, seconds = 30;
  final bytes = ByteData(44 + rate * seconds * 2);
  void text(int at, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(at + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, rate * seconds * 2, Endian.little);
  for (var i = 0; i < rate * seconds; i++) {
    bytes.setInt16(
      44 + i * 2,
      (800 * math.sin(2 * math.pi * 220 * i / rate)).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

Future<void> frames(WidgetTester tester, {int count = 6}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native daily practice, four-language library and real audio survive navigation',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PracticeService.storageKey);
      await prefs.setString('language_code', 'en');
      await prefs.setBool('has_launched', true);
      final fixture = PremiumFixture();
      runApp(app.MyApp(premiumBackend: fixture));
      await tester.pump();
      for (
        var i = 0;
        i < 120 && find.byKey(const Key('glass_tab_2')).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const Key('glass_tab_2')), findsOneWidget);
      final ctx = tester.element(find.byType(app.MainScreen));
      final premium = ctx.read<PremiumService>();
      await premium.connect();
      final practice = ctx.read<PracticeService>();
      await practice.initialize();
      final language = ctx.read<LanguageService>();
      final settings = NativeSettingsService();
      final notificationPrefs = await settings.getNotificationSettings();
      expect(
        await settings.updateNotificationSettings(
          notificationPrefs.copyWith(enabled: true),
        ),
        isTrue,
      );
      final permission = await settings.checkAllPermissions();
      Future<List<int>> routineNotificationIds() async =>
          (await NotificationService().flutterLocalNotificationsPlugin
                  .pendingNotificationRequests())
              .where((request) => request.id >= 1500000000)
              .map((request) => request.id)
              .toList();
      await practice.saveRoutine(
        const PracticeRoutine(
          id: 'ci-morning',
          title: 'CI practice fixture',
          steps: ['chant', 'read'],
          weekdays: [DateTime.monday],
          reminderMinute: 540,
        ),
      );
      await frames(tester);
      if (permission.hasNotificationPermission) {
        for (
          var i = 0;
          i < 30 && (await routineNotificationIds()).isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(
          await routineNotificationIds(),
          isNotEmpty,
          reason:
              'Consented premium routine must register real native reminders',
        );
      } else {
        expect(
          await routineNotificationIds(),
          isEmpty,
          reason: 'Denied notification permission must leave no routine alerts',
        );
      }
      await binding.convertFlutterSurfaceToImage();
      for (final code in ['en', 'ta', 'hi', 'te']) {
        await language.changeLanguage(code);
        await frames(tester);
        await tapAppTab(tester, 2);
        await frames(tester);
        expect(find.byType(PracticeScreen).hitTestable(), findsOneWidget);
        expect(
          find.byKey(const Key('practice_vrat')).hitTestable(),
          findsOneWidget,
        );
        await binding.takeScreenshot('daily_practice_$code');
        await tapAppTab(tester, 3);
        await frames(tester);
        expect(
          find.byKey(const Key('library_search')).hitTestable(),
          findsOneWidget,
        );
        await binding.takeScreenshot('daily_library_$code');
        expect(tester.takeException(), isNull);
      }
      final file = File('${Directory.systemTemp.path}/devotion-ci-tone.wav');
      await file.writeAsBytes(testTone());
      final audio = ctx.read<DevotionAudioService>();
      await audio.select(
        DevotionTrack(
          id: 'ci-native-audio-fixture',
          premium: false,
          cleared: true,
          source: file.uri.toString(),
          sha256: '',
        ),
      );
      await frames(tester, count: 10);
      expect(audio.current?.id, 'ci-native-audio-fixture');
      expect(audio.duration.inSeconds, 30);
      expect(audio.position, greaterThan(Duration.zero));
      await tapAppTab(tester, 2);
      await frames(tester);
      expect(
        find.byKey(const Key('devotion_mini_player')).hitTestable(),
        findsOneWidget,
      );
      await practice.start();
      await tester.scrollUntilVisible(
        find.byKey(const Key('practice_start')),
        100,
        scrollable: find.byType(Scrollable).hitTestable().last,
      );
      await tester.tap(find.byKey(const Key('practice_start')));
      await frames(tester);
      expect(find.byType(JapaScreen), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('japa_increment')));
      await tester.tap(find.byKey(const Key('japa_increment')));
      await frames(tester);
      expect(practice.count, 1);
      expect(audio.current?.id, 'ci-native-audio-fixture');
      await binding.takeScreenshot('daily_native_audio_with_japa');
      await practice.pause();
      final restored = PracticeService(premium: () => true);
      await restored.initialize();
      expect(restored.count, 1);
      restored.dispose();
      await practice.finish();
      expect(practice.sessions.single['count'], 1);
      fixture.premium = false;
      await premium.connect();
      await frames(tester);
      expect(practice.sessions.single['count'], 1);
      for (
        var i = 0;
        i < 30 && (await routineNotificationIds()).isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        await routineNotificationIds(),
        isEmpty,
        reason:
            'Premium expiry cancels routine alerts without deleting history',
      );
      await audio.stop();
      audio.dismiss();
      await file.delete();
      await returnToMain(tester);
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
