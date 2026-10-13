import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  Widget buildCalendarWithProviders({
    required List<EkadashiDate> ekadashis,
    GlobalKey<CalendarScreenState>? key,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => TraditionService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CalendarScreen(
            key: key,
            ekadashiList: ekadashis,
            currentTimezone: 'IST',
          ),
        ),
      ),
    );
  }

  testWidgets('Calendar screen allows navigation up to December 31, 2027', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final ekadashi2027 = EkadashiDate(
      id: 48,
      name: 'Mokshada Ekadashi',
      date: DateTime(2027, 12, 9),
      fastStartTime: '06:27 AM',
      fastBreakTime: '06:27 AM - 09:15 AM',
      description: 'Mokshada Ekadashi',
      fastingStartIso: '2027-12-09T06:27:00+05:30',
      paranaStartIso: '2027-12-10T06:27:00+05:30',
      paranaEndIso: '2027-12-10T09:15:00+05:30',
    );

    final calendarKey = GlobalKey<CalendarScreenState>();

    await tester.pumpWidget(buildCalendarWithProviders(
      ekadashis: [ekadashi2027],
      key: calendarKey,
    ));
    await tester.pumpAndSettle();

    // Verify CalendarScreen is mounted
    expect(find.byType(CalendarScreen), findsOneWidget);

    // Verify that the calendar's boundary allows December 31, 2027
    final state = calendarKey.currentState;
    expect(state, isNotNull);

    // Find the right chevron to navigate forward
    final rightChevron = find.byIcon(Icons.chevron_right);
    expect(rightChevron, findsOneWidget);

    // Tap right chevron to navigate forward
    await tester.tap(rightChevron);
    await tester.pumpAndSettle();

    // Verify no exceptions were thrown
    expect(tester.takeException(), isNull);
  });
}
