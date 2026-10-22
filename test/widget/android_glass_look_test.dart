import 'package:clock/clock.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/app_harness.dart';

void main() {
  for(final code in AppLanguage.codes) {
    for(final dark in [true,false]) {
      testWidgets('optional Glass Look retains navigation geometry and state $code dark=$dark', (tester) async {
        final harness=AppHarness();
        await tester.runAsync(()=>harness.install(preferences:{'language_code':code,'is_dark_mode':dark}));
        addTearDown(harness.uninstall);
        tester.view.physicalSize=const Size(393,844);
        tester.view.devicePixelRatio=1;
        tester.view.padding=const FakeViewPadding(top:24,bottom:24);
        addTearDown(tester.view.reset);
        await withClock(Clock.fixed(DateTime.utc(2026,10,22,7,15)), () async {
          await tester.pumpWidget(harness.app());
          await tester.pumpAndSettle();
          List<Rect> tabs()=>List.generate(5,(i)=>tester.getRect(find.byKey(Key('glass_tab_$i'))));
          final before=tabs();
          await tester.tap(find.byKey(const Key('glass_tab_1')));
          await tester.pumpAndSettle();
          tester.state<CalendarScreenState>(find.byType(CalendarScreen)).selectDate(DateTime(2026,10,20));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('glass_tab_4')));
          await tester.pumpAndSettle();
          final toggle=find.byKey(const Key('settings_glass_look'));
          expect(toggle,findsOneWidget);
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          final off=tester.widget<SwitchListTile>(find.descendant(of:toggle,matching:find.byType(SwitchListTile)));
          expect(off.value,isFalse);
          await tester.tap(find.descendant(of:toggle,matching:find.byType(Switch)));
          await tester.pumpAndSettle();
          expect(tabs(),before);
          await tester.tap(find.byKey(const Key('glass_tab_1')));
          await tester.pumpAndSettle();
          expect(tester.widget<TableCalendar>(find.byType(TableCalendar)).selectedDayPredicate!(DateTime(2026,10,20)),isTrue);
          await tester.tap(find.byKey(const Key('glass_tab_0')));
          await tester.pumpAndSettle();
          expect(tabs(),before);
          final details=find.byKey(const Key('view_details'));
          expect(details.hitTestable(),findsOneWidget);
          expect(tester.getRect(details).bottom,lessThan(tester.getRect(find.byKey(const Key('glass_navigation_bar'))).top));
          await tester.tap(find.byKey(const Key('glass_tab_4')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(find.descendant(of:toggle,matching:find.byType(Switch)));
          await tester.pumpAndSettle();
          expect(tabs(),before);
          expect(tester.takeException(),isNull);
          await tester.pumpWidget(const SizedBox());
        });
      });
    }
  }
}
