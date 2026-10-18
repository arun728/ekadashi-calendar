import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/journey_rewards_views.dart';
import 'package:ekadashi_calendar/services/journey_rewards.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'annual overview, mandala and year selector precede existing metrics',
    (tester) async {
      final tracker = VratTrackerService();
      await tracker.init();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tracker),
            ChangeNotifierProvider(create: (_) => LanguageService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VratTrackerScreen(
                ekadashiList: [],
                currentTimezone: 'Asia/Kolkata',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('journey_year_points')), findsOneWidget);
      expect(find.byKey(const Key('journey_mandala')), findsOneWidget);
      expect(find.byKey(const Key('journey_overview_year')), findsOneWidget);
      await tester.tap(find.byKey(const Key('journey_tab_achievements')));
      await tester.pumpAndSettle();
      for (final group in [
        'all',
        'milestones',
        'consistency',
        'encouragement',
        'annual',
      ]) {
        expect(find.byKey(Key('journey_badge_filter_$group')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('journey_badge_first_vrat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('journey_badge_detail')), findsOneWidget);
      expect(find.text('Fully observe your first Ekadashi.'), findsWidgets);
    },
  );
  for(final code in ['en','hi','ta','te','gu','bn']) {
    testWidgets('$code Journey overview fits narrow screens with large text',(tester)async {
      tester.view.physicalSize=const Size(320,900);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final tracker=VratTrackerService();await tracker.init();final lang=LanguageService();await lang.changeLanguage(code);
      final summary=JourneyRewards.calculate(occurrences:[],history:[],completeYears:{});
      await tester.pumpWidget(MultiProvider(providers:[ChangeNotifierProvider.value(value:tracker),ChangeNotifierProvider.value(value:lang)],child:MaterialApp(home:MediaQuery(data:const MediaQueryData(textScaler:TextScaler.linear(1.4)),child:Scaffold(body:SingleChildScrollView(child:JourneyOverviewPanel(summary:summary,year:2026)))))));
      await tester.pumpAndSettle();expect(tester.takeException(),isNull);
    });
  }

}
