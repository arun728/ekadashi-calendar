import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The top bar sits a little below the status bar, as the iPhone's
/// navigation bar does (it was cramped against the clock on Android), and
/// months slide in 0.25 s on both platforms (CalendarView.monthSlide).
void main() {
  testWidgets('the top bar leaves room under the status bar', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: ShellTopBar(
            title: 'Ekadashi Calendar',
            onSearch: () {},
            leading: [TextButton(onPressed: () {}, child: const Text('Today'))],
          ),
        ),
      ),
    );
    final capsules = find.byType(GlassPanel);
    for (final rect in capsules.evaluate().map(
      (e) => tester.getRect(find.byWidget(e.widget)),
    )) {
      expect(
        rect.top,
        greaterThanOrEqualTo(32 + ShellTopBar.topGap),
        reason: '$rect',
      );
    }
    expect(ShellTopBar.topGap, 10);
    expect(
      const ShellTopBar(title: '', onSearch: _noop).preferredSize.height,
      kToolbarHeight + ShellTopBar.topGap,
    );
  });

  test('months slide in 0.25 s', () {
    expect(CalendarScreenState.monthSlide, const Duration(milliseconds: 250));
  });
}

void _noop() {}
