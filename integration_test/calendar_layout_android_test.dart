import 'package:ekadashi_calendar/main.dart' as app;
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Every 2026 and 2027 month fits on the compact Android device', (
    tester,
  ) async {
    // Keep this layout run isolated from saved app preferences.
    SharedPreferences.setMockInitialValues({
      'has_launched': true,
      'language_code': 'en',
      'is_dark_mode': true,
    });
    app.main();
    Future<void> frames() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    final calendarTab = find.byKey(const Key('glass_tab_1'));
    for (var i = 0; i < 60 && calendarTab.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(calendarTab, findsOneWidget);
    await tester.tap(calendarTab);
    final grid = find.byWidgetPredicate((widget) => widget is TableCalendar);
    for (var i = 0; i < 60 && grid.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(grid, findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await frames();
    final state = tester.state<CalendarScreenState>(
      find.byType(CalendarScreen),
    );
    for (final year in [2026, 2027]) {
      for (var month = 1; month <= 12; month++) {
        final last = DateTime(year, month + 1, 0);
        state.selectDate(last);
        await frames();
        final calendar = tester.widget<TableCalendar>(grid);
        expect(calendar.focusedDay.year, year);
        expect(calendar.focusedDay.month, month);
        expect(calendar.selectedDayPredicate!(last), isTrue);
        final weeks = ((DateTime(year, month).weekday % 7 + last.day) / 7)
            .ceil();
        final gridBounds = tester.getRect(grid);
        final detailsBounds = tester.getRect(
          find.byKey(const Key('calendar_day_details')),
        );
        expect(gridBounds.height, closeTo(28 + weeks * 48, 0.5));
        expect(
          detailsBounds.top - gridBounds.bottom,
          greaterThanOrEqualTo(11),
          reason: '$year-$month: details must not cover the final week',
        );
        expect(tester.takeException(), isNull, reason: '$year-$month');
        await binding.takeScreenshot('calendar-android-$year-$month');
        debugPrint(
          'ANDROID_CALENDAR $year-$month weeks=$weeks '
          'grid=$gridBounds details=$detailsBounds',
        );
      }
    }
  });
}
