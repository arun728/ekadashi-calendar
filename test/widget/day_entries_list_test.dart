import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/models/calendar_day_merge.dart';
import 'package:ekadashi_calendar/screens/widgets/day_entries_list.dart';

void main() {
  testWidgets('renders Ekadashi, Google, Custom with distinct titles',
      (tester) async {
    final items = [
      const DayListItem(
        kind: DayItemKind.ekadashi,
        title: 'Nirjala Ekadashi',
        editable: false,
      ),
      DayListItem(
        kind: DayItemKind.google,
        title: 'Holiday',
        startAt: DateTime(2027, 6, 14),
        isAllDay: true,
        editable: false,
      ),
      DayListItem(
        kind: DayItemKind.custom,
        title: 'Prep fruits',
        startAt: DateTime(2027, 6, 14, 8, 0),
        endAt: DateTime(2027, 6, 14, 9, 0),
        entryId: 'c1',
        editable: true,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: DayEntriesList(items: items))),
    );
    expect(find.text('Nirjala Ekadashi'), findsOneWidget);
    expect(find.text('Holiday'), findsOneWidget);
    expect(find.text('Prep fruits'), findsOneWidget);
  });

  testWidgets('empty state message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DayEntriesList(items: [])),
      ),
    );
    expect(find.text('No entries for this day'), findsOneWidget);
  });
}
