import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/screens/widget_preview_screen.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 6 (docs/ROADMAP.md): the preview shows the two widgets, Ekadashi
/// (today with progress, or the next one and the days to go) and Upcoming.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('en', null);
  });

  final now = DateTime(2026, 10, 8, 12);

  EkadashiDate ekadashi(int id, String name, DateTime date) {
    final start = DateTime(date.year, date.month, date.day, 6);
    final parana = start.add(const Duration(days: 1));
    return EkadashiDate(
      id: id,
      name: name,
      date: DateTime(date.year, date.month, date.day),
      fastBreakTime: '06:24 AM – 08:42 AM',
      fastStartTime: '06:00 AM',
      description: '$name description',
      fastingStartIso: start.toIso8601String(),
      paranaStartIso: parana.toIso8601String(),
      paranaEndIso: parana.add(const Duration(hours: 3)).toIso8601String(),
    );
  }

  final upcoming = [
    ekadashi(3, 'Papankusha Ekadashi', DateTime(2026, 10, 10)),
    ekadashi(4, 'Rama Ekadashi', DateTime(2026, 10, 26)),
    ekadashi(5, 'Devaprabodhini Ekadashi', DateTime(2026, 11, 10)),
    ekadashi(6, 'Utpanna Ekadashi', DateTime(2026, 11, 25)),
  ];

  Future<void> pump(
    WidgetTester tester,
    List<EkadashiDate> list, {
    Size size = const Size(1080, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageService>(
        create: (_) => LanguageService(),
        child: ChangeNotifierProvider(
          create: (_) => VratTrackerService(),
          child: MaterialApp(
            home: WidgetPreviewScreen(ekadashiList: list, now: now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the two widgets: Ekadashi and Upcoming', (tester) async {
    await pump(tester, upcoming);
    expect(find.byKey(const Key('card_ekadashi')), findsOneWidget);
    expect(find.byKey(const Key('card_upcoming_ekadashi')), findsOneWidget);
    expect(find.byKey(const Key('card_today_ekadashi')), findsNothing);
    expect(find.byKey(const Key('card_next_ekadashi')), findsNothing);
  });

  testWidgets('before an Ekadashi it shows the next one and the days to go', (
    tester,
  ) async {
    await pump(tester, upcoming);
    final card = find.byKey(const Key('card_ekadashi'));
    expect(
      find.descendant(of: card, matching: find.text('NEXT EKADASHI')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Papankusha Ekadashi')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('2 days to go')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
      findsNothing,
    );

    // The Upcoming list starts with the next Ekadashi.
    final list = find.byKey(const Key('card_upcoming_ekadashi'));
    for (final name in ['Papankusha Ekadashi', 'Rama Ekadashi']) {
      expect(find.descendant(of: list, matching: find.text(name)), findsOne);
    }

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(DetailsScreen), findsOneWidget);
  });

  testWidgets('on an Ekadashi it shows today and the progress of the fast', (
    tester,
  ) async {
    await pump(tester, [
      ekadashi(2, 'Indira Ekadashi', DateTime(2026, 10, 8)),
      ...upcoming,
    ]);
    final card = find.byKey(const Key('card_ekadashi'));
    expect(
      find.descendant(of: card, matching: find.text('TODAY IS EKADASHI')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Indira Ekadashi')),
      findsOneWidget,
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
    );
    // 06:00 to 06:00 the next day; 12:00 is a quarter of the way.
    expect(bar.value, closeTo(0.25, 0.01));
    expect(
      find.descendant(of: card, matching: find.text('25% of the fast done')),
      findsOneWidget,
    );
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    await pump(tester, [
      ekadashi(2, 'Indira Ekadashi', DateTime(2026, 10, 8)),
      ...upcoming,
    ], size: const Size(320 * 2, 568 * 2));
    expect(find.byKey(const Key('card_ekadashi')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
