// SHOTS-ONLY: drives the app for Play Store screenshots and video. Never shipped.
// The host script (rec-android.sh) watches the log for "SHOT:<name>" and
// captures the emulator screen with adb while the app is held still.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/data/sqflite_calendar_entry_repository.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';

const session = String.fromEnvironment('SHOTS_SESSION', defaultValue: 'jan');

/// A realistic year: mostly observed, a few partial and missed, mixed methods.
const plan = <int, (String, String?)>{
  1: ('observed', 'fullFast'), 2: ('partial', 'oneMeal'), 3: ('observed', 'fruitsMilk'),
  4: ('observed', 'fullFast'), 5: ('observed', 'waterOnly'), 6: ('missed', null),
  7: ('observed', 'fruitsMilk'), 8: ('observed', 'fullFast'), 9: ('partial', 'oneMeal'),
  10: ('observed', 'fullFast'), 11: ('observed', 'fruitsMilk'), 12: ('observed', 'waterOnly'),
  14: ('observed', 'fullFast'), 15: ('missed', null), 16: ('observed', 'fruitsMilk'),
  17: ('partial', 'oneMeal'), 18: ('observed', 'fullFast'), 19: ('observed', 'fullFast'),
  20: ('observed', 'fruitsMilk'), 21: ('observed', 'fullFast'),
};

Future<void> seedCalendar() async {
  final repo = SqfliteCalendarEntryRepository();
  await repo.init();
  const holidays = [
    ('2027-01-14', 'Lohri'), ('2027-01-15', 'Makar Sankranti / Pongal'), ('2027-01-26', 'Republic Day'),
    ('2027-02-11', 'Vasant Panchami'), ('2027-03-06', 'Maha Shivaratri'), ('2027-03-21', 'Holika Dahan'),
    ('2027-03-22', 'Holi'), ('2027-04-07', 'Ugadi / Gudi Padwa'), ('2027-04-15', 'Ram Navami'),
    ('2027-04-20', 'Hanuman Jayanti'), ('2027-05-09', 'Akshaya Tritiya'), ('2027-07-05', 'Rath Yatra'),
    ('2027-07-18', 'Guru Purnima'), ('2027-08-13', 'Varalakshmi Vratam'), ('2027-08-15', 'Independence Day'),
    ('2027-08-17', 'Raksha Bandhan'), ('2027-08-25', 'Janmashtami'), ('2027-09-12', 'Onam'),
    ('2027-10-02', 'Gandhi Jayanti'), ('2027-10-09', 'Dussehra'), ('2027-10-18', 'Karwa Chauth'),
    ('2027-10-27', 'Dhanteras'), ('2027-10-29', 'Diwali'), ('2027-10-31', 'Bhai Dooj'),
    ('2027-11-04', 'Chhath Puja'), ('2027-12-11', 'Karthigai Deepam'), ('2027-12-25', 'Christmas'),
  ];
  var i = 0;
  for (final (day, title) in holidays) {
    final start = DateTime.parse(day);
    await repo.upsert(CalendarEntry(
      id: 'shots-$i', title: title, startAt: start, endAt: start.add(const Duration(days: 1)),
      isAllDay: true, source: CalendarEntrySource.google, googleEventId: 'g$i',
      calendarName: 'Holidays in India', accountId: 'demo@gmail.com', calendarId: 'holidays',
      updatedAt: start,
    ));
    i++;
  }
  const timed = [
    ('2027-01-05T18:30', 60, 'Mandir darshan with family', true),
    ('2027-01-10T10:00', 120, 'Satyanarayan Katha', true),
    ('2027-01-19T07:00', 60, 'Hanuman Chalisa path', false),
    ('2027-01-30T19:00', 90, 'Bhajan sandhya', false),
    ('2027-03-20T18:00', 60, 'Buy colours and gujiya', false),
    ('2027-07-25T07:00', 60, 'Vishnu Sahasranama path', false),
    ('2027-10-24T11:00', 120, 'Diwali shopping', false),
    ('2027-10-29T18:30', 90, 'Lakshmi Puja at home', true),
  ];
  for (final (at, minutes, title, google) in timed) {
    final start = DateTime.parse(at);
    await repo.upsert(CalendarEntry(
      id: 'shots-$i', title: title,
      startAt: google ? start.toUtc() : start, endAt: (google ? start.toUtc() : start).add(Duration(minutes: minutes)),
      source: google ? CalendarEntrySource.google : CalendarEntrySource.custom,
      googleEventId: google ? 'g$i' : null, calendarName: google ? 'Family' : null,
      accountId: google ? 'demo@gmail.com' : null, calendarId: google ? 'primary' : null,
      updatedAt: start,
    ));
    i++;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store shots ($session)', (tester) async {
    Future<void> hold(double s) async {
      final end = DateTime.now().add(Duration(milliseconds: (s * 1000).round()));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> shot(String name, {double settle = 1.5}) async {
      await hold(settle);
      debugPrint('SHOT:$name');
      await hold(2.5); // the host captures during this pause
    }

    Future<bool> ready(Finder f, {int seconds = 30}) async {
      for (var i = 0; i < seconds * 4 && f.evaluate().isEmpty; i++) {
        await hold(0.25);
      }
      return f.evaluate().isNotEmpty;
    }

    Future<bool> tap(String id, {int seconds = 20, double after = 1.2}) async {
      final f = find.byKey(Key(id));
      if (!await ready(f, seconds: seconds)) {
        debugPrint('MISSING:$id');
        return false;
      }
      // Prefer a match already on screen: ensureVisible on an off-screen page
      // (Home's neighbouring Ekadashi) would scroll to that page.
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      Finder target = f.first;
      for (var k = 0; k < f.evaluate().length; k++) {
        final c = tester.getCenter(f.at(k));
        if (c.dx > 0 && c.dx < size.width && c.dy > 0 && c.dy < size.height) {
          target = f.at(k);
          break;
        }
      }
      await tester.ensureVisible(target);
      await hold(0.3);
      await tester.tap(target, warnIfMissed: false);
      await hold(after);
      return true;
    }

    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await hold(1.2);
    }

    Future<void> pickYear(String menu, String year) async {
      if (!await tap(menu, seconds: 10, after: 1.2)) return;
      final item = find.descendant(of: find.byType(PopupMenuItem<int>), matching: find.text(year));
      if (await ready(item, seconds: 5)) {
        await tester.tap(item.last, warnIfMissed: false);
        await hold(1.5);
      } else {
        debugPrint('MISSING:year $year in $menu');
        await back();
      }
    }

    Future<void> marker(String name) async {
      debugPrint('MARK:$name');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('has_launched', true);
    await prefs.setString('language_code', 'en');
    await prefs.setBool('dark_mode', true);
    await prefs.setString('ekadashi_tradition', 'gaudiya');
    await prefs.setInt('ekadashi_year', 2027);
    await prefs.setString('premium_plan_hint', 'yearly');
    await seedCalendar();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    app.main();
    await ready(find.byKey(const Key('view_details')), seconds: 60);
    Future<void> settled() async {
      for (var i = 0; i < 240; i++) {
        if (find.byKey(const Key('home_recalculating')).evaluate().isEmpty &&
            find.byKey(const Key('home_calculating')).evaluate().isEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
        await hold(0.25);
      }
      await hold(1.5);
    }
    await settled();

    if (session == 'jan') {
      await shot('home');
      await tap('language_menu');
      await shot('language-menu');
      await back();
      await tap('home_tradition_menu');
      await shot('tradition-menu');
      await back();
      await tap('home_share_card', after: 2.5);
      await shot('share-card');
      await back();

      // Journey: record 2026 with a realistic mix.
      await tap('glass_tab_2', after: 2);
      await shot('journey-empty');
      await tap('journey_tab_history', after: 2);
      await pickYear('journey_history_year_menu', '2026');
      await ready(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('journey_row_')), seconds: 30);
      for (final n in plan.keys) {
        final id = 'journey_row_ekadashi:2026:${n.toString().padLeft(2, '0')}';
        final row = find.byKey(Key(id));
        for (var k = 0; k < 40 && row.evaluate().isEmpty; k++) {
          final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
          if (lists.evaluate().isEmpty) { await hold(0.5); continue; }
          await tester.drag(lists.last, const Offset(0, -300), warnIfMissed: false);
          await hold(0.4);
        }
        if (!await tap(id, after: 1.5)) continue;
        final (status, method) = plan[n]!;
        if (status != 'observed') await tap('vrat_status_$status', seconds: 4, after: 0.5);
        if (method != null) await tap('vrat_method_$method', seconds: 4, after: 0.4);
        await tap('vrat_record_save', seconds: 5, after: 1.8);
        for (final close in ['journey_celebration_close', 'achievement_unlock_ok']) {
          if (find.byKey(Key(close)).evaluate().isNotEmpty) await tap(close, after: 1.2);
        }
      }
      await tap('journey_tab_overview', after: 2);
      await pickYear('journey_overview_year', '2026');
      await tester.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last, const Offset(0, 2000), warnIfMissed: false);
      await shot('journey-overview', settle: 2);
      await tap('journey_share_year', after: 3);
      await shot('journey-share', settle: 2);
      await back();
      await tap('journey_tab_statistics', after: 2);
      await pickYear('journey_stats_year_menu', '2026');
      await shot('journey-statistics', settle: 2);

      // Panchang.
      await tap('glass_tab_3', after: 4);
      await tap('panchang_tab_daily', after: 3);
      await shot('panchang-daily', settle: 2);
      await tap('panchang_tab_muhurta', after: 3);
      await shot('panchang-muhurta', settle: 2);
      await tap('panchang_tab_rashi', after: 3);
      await shot('panchang-rashi', settle: 2);
    } else if (session == 'share') {
      final f = find.byKey(const Key('home_share_card'));
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      debugPrint('DBG screen $size count ${f.evaluate().length}');
      for (var k = 0; k < f.evaluate().length; k++) {
        debugPrint('DBG $k ${tester.getCenter(f.at(k))} hit=${f.at(k).hitTestable().evaluate().length}');
      }
      final onScreen = [
        for (var k = 0; k < f.evaluate().length; k++)
          if (tester.getCenter(f.at(k)).dx > 0 && tester.getCenter(f.at(k)).dx < size.width) k,
      ];
      debugPrint('DBG onScreen $onScreen');
      await tester.tapAt(tester.getCenter(f.at(onScreen.first)));
      await hold(3);
      await shot('share-card');
      await back();
    } else if (session == 'widgets') {
      Future<void> tapText(String t) async {
        final f = find.text(t);
        if (!await ready(f, seconds: 8)) { debugPrint('MISSING:text $t'); return; }
        await tester.ensureVisible(f.last);
        await hold(0.3);
        await tester.tap(f.last, warnIfMissed: false);
        await hold(1.8);
      }
      await tap('glass_tab_4', after: 2);
      await tapText('Widget Preview');
      await hold(2);
      await tapText('Medium');
      await shot('w-ekadashi-medium');
      await tapText('Small');
      await shot('w-ekadashi-small');
      await tapText('Large');
      await shot('w-ekadashi-large');
      await tapText('Upcoming Ekadashis');
      await tapText('Medium');
      await shot('w-upcoming-medium');
      await tapText('Large');
      await shot('w-upcoming-large');
    } else if (session == 'video') {
      // Each scene: the host starts screenrecord on REC:<name> and stops on STOP:<name>.
      Future<void> scene(String name, double seconds, Future<void> Function() act) async {
        debugPrint('REC:$name');
        await hold(1.2); // screenrecord start-up
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        await act();
        while (DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        debugPrint('STOP:$name');
        await hold(1.0);
      }
      Future<void> slowScroll(double dy, double seconds) async {
        final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
        if (lists.evaluate().isEmpty) return;
        final g = await tester.startGesture(tester.getCenter(lists.last));
        final steps = (seconds * 60).round();
        for (var i = 0; i < steps; i++) {
          await g.moveBy(Offset(0, dy / steps));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await hold(0.6);
      }
      Future<void> tapText(String t) async {
        final f = find.text(t);
        if (!await ready(f, seconds: 8)) { debugPrint('MISSING:text $t'); return; }
        final v = f.hitTestable();
        await tester.tap(v.evaluate().isNotEmpty ? v.first : f.last, warnIfMissed: false);
        await hold(1.2);
      }
      Future<void> tapOnScreen(String id) async {
        final f = find.byKey(Key(id));
        if (!await ready(f, seconds: 10)) { debugPrint('MISSING:$id'); return; }
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        for (var k = 0; k < f.evaluate().length; k++) {
          final c = tester.getCenter(f.at(k));
          if (c.dx > 0 && c.dx < size.width && c.dy > 0 && c.dy < size.height) {
            await tester.tapAt(c);
            return;
          }
        }
        debugPrint('OFFSCREEN:$id');
      }

      // Off camera: record 2026 so Journey has points.
      await tap('glass_tab_2', after: 2);
      await tap('journey_tab_history', after: 2);
      await pickYear('journey_history_year_menu', '2026');
      for (final n in plan.keys) {
        final id = 'journey_row_ekadashi:2026:${n.toString().padLeft(2, '0')}';
        final row = find.byKey(Key(id));
        for (var k = 0; k < 40 && row.evaluate().isEmpty; k++) {
          final lists = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
          if (lists.evaluate().isEmpty) { await hold(0.5); continue; }
          await tester.drag(lists.last, const Offset(0, -300), warnIfMissed: false);
          await hold(0.4);
        }
        if (!await tap(id, after: 1.5)) continue;
        final (status, method) = plan[n]!;
        if (status != 'observed') await tap('vrat_status_$status', seconds: 4, after: 0.5);
        if (method != null) await tap('vrat_method_$method', seconds: 4, after: 0.4);
        await tap('vrat_record_save', seconds: 5, after: 1.8);
        for (final close in ['journey_celebration_close', 'achievement_unlock_ok']) {
          if (find.byKey(Key(close)).evaluate().isNotEmpty) await tap(close, after: 1.2);
        }
      }
      await tap('glass_tab_0', after: 3);
      await settled();
      await hold(2);

      await scene('home', 4.5, () async {
        await hold(1.6);
        await tapOnScreen('home_next');
        await hold(1.6);
        await tapOnScreen('home_previous');
      });
      await scene('language', 4.5, () async {
        await hold(0.6);
        await tapOnScreen('language_menu');
        await hold(1.0);
        await tapText('हिंदी');
      });
      // Back to English off camera.
      await tapOnScreen('language_menu');
      await hold(1);
      await tapText('English');
      await settled();
      await scene('share', 4.0, () async {
        await hold(0.6);
        await tapOnScreen('home_share_card');
      });
      await back();
      await scene('calendar', 4.5, () async {
        await tapOnScreen('glass_tab_1');
        await hold(1.8);
        await tapText('15');
      });
      await tap('glass_tab_3', after: 4);
      await tap('panchang_tab_keydays', after: 2);
      await scene('festivals', 4.5, () async {
        await hold(0.4);
        await tapOnScreen('panchang_key_filter_festival');
        await hold(1.0);
        await slowScroll(-500, 2.0);
      });
      await scene('panchang', 4.5, () async {
        await tapOnScreen('panchang_tab_daily');
        await hold(1.4);
        await slowScroll(-700, 2.4);
      });
      await tap('glass_tab_2', after: 2);
      await tap('journey_tab_overview', after: 1.5);
      await pickYear('journey_overview_year', '2026');
      await tester.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last, const Offset(0, 2000), warnIfMissed: false);
      await hold(1.5);
      await scene('journey', 4.5, () async {
        await hold(0.6);
        await slowScroll(-600, 2.6);
      });
      await tester.drag(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last, const Offset(0, 3000), warnIfMissed: false);
      await hold(1.2);
      await scene('journey-share', 4.0, () async {
        await hold(0.4);
        await tapOnScreen('journey_share_year');
      });
      await back();
      await tap('glass_tab_4', after: 2);
      await tapText('Widget Preview');
      await tapText('Medium');
      await scene('widgets', 5.0, () async {
        await hold(1.2);
        await tapText('Small');
        await hold(0.6);
        await tapText('Upcoming Ekadashis');
        await hold(0.4);
        await tapText('Large');
      });
    } else if (session == 'oct') {
      await tap('glass_tab_1', after: 3);
      await shot('calendar-diwali', settle: 2);
      await tap('glass_tab_3', after: 4);
      await tap('panchang_tab_keydays', after: 3);
      await tap('panchang_key_filter_festival', after: 2);
      await shot('panchang-festivals-oct', settle: 2);
    }
    await marker('done');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
