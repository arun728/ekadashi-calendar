// Separate integration-test entrypoint. No clock override is linked into main.dart.
import 'package:clock/clock.dart';
import 'package:ekadashi_calendar/services/display_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/services/ekadashi_settings.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/screens/widget_preview_screen.dart';
import 'package:ekadashi_calendar/widgets/native_widget_preview.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android lifecycle screenshots and exact boundaries', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_launched', true);
    await prefs.setInt('ekadashi_year', 2026);
    await prefs.setString('language_code', 'en');
    await prefs.setBool('is_dark_mode', true);
    var now = DateTime.parse('2026-10-22T00:00:00+05:30');
    await withClock(Clock(() => now), () async {
      DisplayClock.setTestClock(() => now);
      addTearDown(() => DisplayClock.setTestClock(null));
      await tester.pumpWidget(const app.MyApp());
      Future<void> frames([int count = 8]) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      for (
        var i = 0;
        i < 300 &&
            find.byKey(const Key('home_page_indicator')).evaluate().isEmpty;
        i++
      ) {
        await frames(1);
      }
      expect(find.byKey(const Key('home_page_indicator')), findsOneWidget);
      final context = tester.element(find.byType(app.MainScreen));
      final settings = context.read<EkadashiSettings>();
      final events = await EkadashiService().engineEkadashis(
        city: settings.city,
        tradition: settings.tradition,
        languageCode: 'en',
        years: settings.years,
      );
      final event = events.firstWhere((e) => e.date == DateTime(2026, 10, 22));
      await binding.convertFlutterSurfaceToImage();
      Future<void> capture(String name) async {
        await frames();
        await binding.takeScreenshot(name);
      }

      Future<void> setTime(DateTime date) async {
        now = date;
        (tester.state(find.byType(app.MainScreen)) as dynamic)
            .refreshLifecycle();
        await tester.tap(find.byKey(const Key('glass_tab_0')));
        await frames();
      }

      await setTime(now);
      expect(
        find.text('06:00:00'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      await capture('android-home-midnight-countdown');
      await setTime(DateTime.parse(event.fastingStartIso));
      expect(find.text('Now'), findsOneWidget);
      await capture('android-home-start-zero');
      final start = DateTime.parse(event.fastingStartIso),
          parana = DateTime.parse(event.paranaStartIso),
          end = DateTime.parse(event.paranaEndIso);
      await setTime(
        start.add(
          Duration(microseconds: parana.difference(start).inMicroseconds ~/ 2),
        ),
      );
      await capture('android-home-halfway');
      await setTime(DateTime.parse('2026-10-23T00:00:00+05:30'));
      expect(find.text('Now'), findsOneWidget);
      await capture('android-home-following-midnight');
      await setTime(parana);
      expect(find.text('Parana'), findsOneWidget);
      await capture('android-home-parana');
      await tester.tap(find.byKey(const Key('glass_tab_1')));
      await frames();
      tester
          .state<CalendarScreenState>(find.byType(CalendarScreen))
          .selectDate(DateTime(2026, 10, 23));
      await frames();
      expect(
        find.byKey(const Key('calendar_lifecycle_status')),
        findsOneWidget,
      );
      await capture('android-calendar-parana-no-dot');
      await tester.tap(find.byKey(const Key('glass_tab_0')));
      await frames();
      await tester.tap(find.byKey(const Key('view_details')));
      await frames();
      final details = find.byKey(const Key('details_lifecycle_status'));
      if (details.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(tester.element(details), alignment: .25);
        await capture('android-details-parana');
      }
      await tester.tap(find.byType(BackButton).first);
      await frames();
      await tester.tap(find.byKey(const Key('glass_tab_4')));
      await frames();
      Navigator.of(tester.element(find.byType(app.MainScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => WidgetPreviewScreen(
            ekadashiList: events,
            currentTimezone: settings.city.timeZoneId,
            locationName: 'Chennai (IN)',
            tradition: settings.tradition.name,
            now: now,
          ),
        ),
      );
      await frames();
      for (final size in ['Small', 'Medium', 'Lock Screen']) {
        await tester.tap(find.text(size));
        await capture(
          'android-widget-parana-${size.replaceAll(' ', '-').toLowerCase()}',
        );
      }
      await tester.tap(find.text('Upcoming Ekadashis'));
      await frames();
      for (final size in ['Medium', 'Large', 'Lock Screen']) {
        await tester.tap(find.text(size));
        await capture(
          'android-widget-upcoming-${size.replaceAll(' ', '-').toLowerCase()}',
        );
      }
      expect(find.byType(NativeWidgetPreview), findsWidgets);
      await tester.tap(find.byType(BackButton).first);
      await frames();
      await setTime(end);
      expect(find.text('Parana'), findsNothing);
      expect(find.text('Rama Ekadashi'), findsOneWidget);
      expect(find.text('21 / 24'), findsOneWidget);
      await capture('android-home-after-parana-end-next');
    });
  });
}
