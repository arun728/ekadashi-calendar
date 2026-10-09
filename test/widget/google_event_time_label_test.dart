import 'package:ekadashi_calendar/models/calendar_day_merge.dart';
import 'package:ekadashi_calendar/models/calendar_entry.dart';
import 'package:ekadashi_calendar/screens/widgets/day_entries_list.dart';
import 'package:ekadashi_calendar/services/google_event_mapper.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a Google event shows the same clock time as Google Calendar', (
    tester,
  ) async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    final lang = LanguageService();
    await lang.changeLanguage('en');
    final entry = GoogleEventMapper.fromApiEvent({
      'id': 'e1',
      'accountId': 'a',
      'calendarId': 'c',
      'summary': 'Test event',
      'start': {'dateTime': '2026-10-06T16:30:00+05:30'},
      'end': {'dateTime': '2026-10-06T17:30:00+05:30'},
    })!;
    final items = CalendarDayMerge.merge(
      day: DateTime(2026, 10, 6),
      ekadashis: const [],
      entries: [entry],
      filter: CalendarFilter.google,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: lang,
        child: MaterialApp(
          home: Scaffold(body: DayEntriesList(items: items)),
        ),
      ),
    );
    // The shared clock format (AppStrings.clock), in the phone's time zone.
    String fmt(DateTime t) => AppStrings.clock(t.hour, t.minute, 'en');
    final instantStart = DateTime.utc(2026, 10, 6, 11, 0).toLocal();
    final instantEnd = DateTime.utc(2026, 10, 6, 12, 0).toLocal();
    final expected = '${fmt(instantStart)} – ${fmt(instantEnd)}';
    expect(find.textContaining(expected), findsOneWidget);
    if (DateTime.now().timeZoneOffset ==
        const Duration(hours: 5, minutes: 30)) {
      // On an IST phone this is exactly what the user created.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '')
                  .replaceAll('\u202f', ' ')
                  .contains('4:30 PM – 5:30 PM'),
        ),
        findsOneWidget,
      );
    }
  });
}
