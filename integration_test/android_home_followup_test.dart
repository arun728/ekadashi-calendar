import 'dart:io';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/services/panchang/calculated_ekadashi.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Home progress, feedback, Calendar language and traditions on Android',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_launched', true);
      await prefs.setString('language_code', 'en');
      await prefs.remove(EkadashiSettings.traditionKey);
      await prefs.setInt(EkadashiSettings.yearKey, 2026);
      await withClock(Clock.fixed(DateTime.utc(2026, 10, 22, 7, 15)), () async {
        await tester.pumpWidget(const app.MyApp());
        Future<void> frames([int count = 8]) async {
          for (var i = 0; i < count; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
        }

        for (
          var i = 0;
          i < 240 &&
              find.byKey(const Key('home_page_indicator')).evaluate().isEmpty;
          i++
        ) {
          await frames(1);
        }
        expect(find.byKey(const Key('home_page_indicator')), findsOneWidget);
        final context = tester.element(find.byType(app.MainScreen));
        final language = context.read<LanguageService>();
        final settings = context.read<EkadashiSettings>();
        expect(settings.tradition, EkadashiTradition.gaudiya);
        await binding.convertFlutterSurfaceToImage();
        final folder = Directory(
          '${await getDatabasesPath()}/android-home-followup',
        );
        await folder.create(recursive: true);
        Future<void> capture(String name) async {
          await frames();
          final bytes = await binding.takeScreenshot(name);
          await File('${folder.path}/$name.png').writeAsBytes(bytes);
        }

        for (final tradition in [
          EkadashiTradition.gaudiya,
          EkadashiTradition.smarta,
        ]) {
          await settings.setTradition(tradition);
          for (final code in AppLanguage.codes) {
            await language.changeLanguage(code);
            await frames(15);
            final ring = find.byKey(const Key('home_fasting_progress'));
            expect(ring, findsOneWidget);
            final today = find.text(language.translate('today'));
            expect(
              tester.getRect(ring).right,
              lessThan(tester.getRect(today).left),
            );
            await capture('home-$code-${tradition.name}');
            await tester.tap(find.byKey(const Key('home_record_vrat')));
            await frames();
            expect(
              find.text(language.translate('journey_record_after_parana')),
              findsOneWidget,
            );
            await capture('feedback-$code-${tradition.name}');
            await frames(25);
            await tester.tap(find.byKey(const Key('glass_tab_1')));
            await frames();
            tester
                .state<CalendarScreenState>(find.byType(CalendarScreen))
                .selectDate(DateTime(2026, 10, 22));
            await frames();
            final texts = tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.byKey(const Key('calendar_ekadashi_card')),
                    matching: find.byType(Text),
                  ),
                )
                .map((t) => t.data ?? '')
                .where(
                  (t) => t.startsWith(language.translate('break_fasting')),
                );
            expect(texts, hasLength(1));
            if (code != 'en') {
              expect(RegExp(r'\b(AM|PM)\b').hasMatch(texts.single), isFalse);
            }
            await capture('calendar-$code-${tradition.name}');
            await tester.tap(find.byKey(const Key('glass_tab_0')));
            await frames();
          }
        }
        await tester.pumpWidget(const SizedBox());
      });
    },
  );
}
