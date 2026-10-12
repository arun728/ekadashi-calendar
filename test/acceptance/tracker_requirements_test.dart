import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/achievement_evaluator.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/record_vrat_dialog.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/achievement_unlock_dialog.dart';

EkadashiDate occurrence(int id, DateTime date) => EkadashiDate(
  id: id,
  name: 'Review occurrence $id',
  date: date,
  fastStartTime: '06:00 AM',
  fastBreakTime: '06:00 AM - 08:00 AM',
  description: '',
);
Future<void> record(
  VratTrackerService s,
  EkadashiDate e,
  List<EkadashiDate> all,
) => s.recordVrat(
  ekadashiOccurrenceId: e.id,
  ekadashiDate: e.date.toIso8601String().substring(0, 10),
  ekadashiName: e.name,
  status: ObservanceStatus.observed,
  occurrences: all,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Future observances must be rejected at service boundary', () async {
    final s = VratTrackerService();
    await s.init();

    final e = occurrence(1, DateTime.now().add(const Duration(days: 100)));
    await record(s, e, [e]);
    expect(s.getRecord(1), isNull);
  });
  test(
    'Legacy opt-out cannot block free recording or achievement progress',
    () async {
      final s = VratTrackerService();
      await s.init();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('vrat_tracker_enabled', false);
      final e = occurrence(1, DateTime(2026, 1, 1));
      await record(s, e, [e]);
      expect(s.getAllRecords(), hasLength(1));
      expect(s.userAchievements['first_vrat']?.isUnlocked, isTrue);
    },
  );
  test('Free tracker permits deleting personal records', () async {
    final s = VratTrackerService();
    await s.init();

    final past = occurrence(1, DateTime(2026, 1, 1));
    await record(s, past, [past]);
    await s.deleteVrat(ekadashiOccurrenceId: past.id, occurrences: [past]);
    expect(s.getRecord(past.id), isNull);
  });
  testWidgets('First achievement save closes the record sheet', (tester) async {
    final s = VratTrackerService();
    final e = occurrence(1, DateTime(2026, 1, 1));
    await s.init(occurrences: [e]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: s),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VratTrackerScreen(ekadashiList: [e], currentTimezone: 'IST'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journey_tab_history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(e.name).hitTestable());
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Record Observance'),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Record Observance'));
    await tester.pumpAndSettle();
    expect(s.getRecord(1), isNotNull);
    expect(find.byType(RecordVratDialog), findsNothing);
    expect(find.byType(AchievementUnlockDialog), findsOneWidget);
    expect(find.text('Achievement Unlocked'), findsOneWidget);
  });
  testWidgets('Tracker must render when device year is absent from calendar', (
    tester,
  ) async {
    final s = VratTrackerService();
    final e = occurrence(1, DateTime(DateTime.now().year - 1, 1, 1));
    await s.init(occurrences: [e]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: s),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: MaterialApp(
          home: VratTrackerScreen(ekadashiList: [e], currentTimezone: 'IST'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journey_tab_history')));
    await tester.pumpAndSettle();
    final historyYear = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>).first,
    );
    expect(historyYear.value, DateTime.now().year);
    await tester.tap(find.byKey(const Key('journey_tab_statistics')));
    await tester.pumpAndSettle();
    final statisticsYear = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>).last,
    );
    expect(statisticsYear.value, DateTime.now().year);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Achievement dialog uses the selected app language', (
    tester,
  ) async {
    final language = LanguageService();
    await language.changeLanguage('ta');
    final achievement = AchievementEvaluator.allAchievements.first;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    AchievementUnlockDialog.show(context, achievement),
                child: const Text('Show achievement'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show achievement'));
    await tester.pumpAndSettle();
    expect(
      find.text(language.translate('achievement_unlocked')),
      findsOneWidget,
    );
    expect(find.text('Achievement Unlocked'), findsNothing);
    expect(tester.takeException(), isNull);
    language.dispose();
  });
}
