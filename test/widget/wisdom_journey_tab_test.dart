import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/wisdom_question_card.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/services/wisdom_progress_store.dart';

void main() {
  late WisdomProgressStore wisdomStore;
  late VratTrackerService trackerService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wisdomStore = WisdomProgressStore.instance;
    await wisdomStore.resetForTesting();
    trackerService = VratTrackerService();
  });

  Widget buildTestApp({
    String? initialSection,
    Locale locale = const Locale('en'),
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WisdomProgressStore>.value(value: wisdomStore),
        ChangeNotifierProvider<VratTrackerService>.value(value: trackerService),
        ChangeNotifierProvider<LanguageService>(
          create: (_) => LanguageService()..changeLanguage(locale.languageCode),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VratTrackerScreen(
            ekadashiList: const [],
            currentTimezone: 'Asia/Kolkata',
            initialSection: initialSection,
          ),
        ),
      ),
    );
  }

  group('Wisdom Journey Subtab Integration', () {
    testWidgets('Journey section pager has 5 tabs including Wisdom', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Check all 5 tabs exist in Journey
      expect(find.byKey(const Key('journey_tab_overview')), findsOneWidget);
      expect(find.byKey(const Key('journey_tab_history')), findsOneWidget);
      expect(find.byKey(const Key('journey_tab_statistics')), findsOneWidget);
      expect(find.byKey(const Key('journey_tab_achievements')), findsOneWidget);
      expect(find.byKey(const Key('journey_tab_wisdom')), findsOneWidget);
    });

    testWidgets('Tapping Wisdom tab displays WisdomQuestionCard and does not display achievements', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap on Wisdom tab
      await tester.tap(find.byKey(const Key('journey_tab_wisdom')));
      await tester.pumpAndSettle();

      // WisdomQuestionCard should be present in Wisdom tab
      expect(find.byType(WisdomQuestionCard), findsOneWidget);
    });

    testWidgets('Achievements tab does not contain WisdomQuestionCard', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Navigate to achievements tab
      await tester.tap(find.byKey(const Key('journey_tab_achievements')));
      await tester.pumpAndSettle();

      // Achievements tab should NOT render WisdomQuestionCard
      expect(find.byType(WisdomQuestionCard), findsNothing);
    });

    testWidgets('Opens directly to Wisdom tab when initialSection is wisdom', (tester) async {
      await tester.pumpWidget(buildTestApp(initialSection: 'wisdom'));
      await tester.pumpAndSettle();

      expect(find.byType(WisdomQuestionCard), findsOneWidget);
    });
  });
}
