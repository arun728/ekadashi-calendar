import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/models/calendar_day_merge.dart';
import 'package:ekadashi_calendar/screens/widgets/calendar_filter_bar.dart';

void main() {
  testWidgets('shows All, Ekadashi, Google, Custom in order', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarFilterBar(
            selected: CalendarDayMerge.defaultFilter,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final labels = ['All', 'Ekadashi', 'Google', 'Custom'];
    for (final l in labels) {
      expect(find.text(l), findsOneWidget);
    }
    // Default selected is Ekadashi
    final ekadashiChip = find.widgetWithText(FilterChip, 'Ekadashi');
    expect(tester.widget<FilterChip>(ekadashiChip).selected, isTrue);
  });

  testWidgets('tapping Google notifies parent', (tester) async {
    CalendarFilter? received;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarFilterBar(
            selected: CalendarFilter.ekadashi,
            onChanged: (f) => received = f,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(received, CalendarFilter.google);
  });
}
