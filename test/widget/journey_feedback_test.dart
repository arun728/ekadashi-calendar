import 'package:flutter/material.dart';
import 'package:ekadashi_calendar/widgets/settings_group.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/services/journey_rewards.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/journey_rewards_views.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/record_vrat_dialog.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/glass_look.dart';
import '../unit/journey_rewards_test.dart' show journeyEvents;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tz.initializeTimeZones();
  });
  Future<void> host(
    WidgetTester tester,
    Widget child, {
    String code = 'en',
    bool glass = false,
  }) async {
    final tracker = VratTrackerService();
    await tracker.init();
    final lang = LanguageService();
    await lang.changeLanguage(code);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: tracker),
          ChangeNotifierProvider.value(value: lang),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GlassLook(enabled: glass, child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'share selects all earned badges and preserves manual deselection',
    (tester) async {
      final badges = JourneyBadgeCatalog.all([]).take(5).toList();
      final progress = JourneyRewards.calculate(
        occurrences: [],
        history: [],
        completeYears: {},
      ).year(2026);
      await host(tester, JourneyShareSheet(progress: progress, badges: badges));
      final switches = tester
          .widgetList<SettingsSwitchTile>(find.byType(SettingsSwitchTile))
          .toList();
      expect(switches.length, 5);
      expect(switches.where((s) => s.value).length, 5);
      JourneyAnnualShareCard card() => tester.widget<JourneyAnnualShareCard>(
        find.byKey(const Key('journey_share_preview')),
      );
      expect(card().badges.map((b) => b.id), badges.map((b) => b.id));
      switches.first.onChanged!(false);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<SettingsSwitchTile>(find.byType(SettingsSwitchTile))
            .where((s) => s.value)
            .length,
        4,
      );
      expect(card().badges.map((b) => b.id), badges.skip(1).map((b) => b.id));
    },
  );

  for (final code in ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
    testWidgets('$code overview omits monetary-rewards sentence', (
      tester,
    ) async {
      final summary = JourneyRewards.calculate(
        occurrences: [],
        history: [],
        completeYears: {},
      );
      await host(
        tester,
        SingleChildScrollView(
          child: JourneyOverviewPanel(summary: summary, year: 2026),
        ),
        code: code,
      );
      final context = tester.element(find.byType(JourneyOverviewPanel));
      final copy = context.read<LanguageService>().translate(
        'ios_journey_personal',
      );
      expect(copy, isNot('ios_journey_personal'));
      expect(find.text(copy), findsNothing);
    });
  }

  testWidgets('Journey metric labels wrap without ellipsis', (tester) async {
    await host(
      tester,
      VratTrackerScreen(
        ekadashiList: journeyEvents(2026),
        currentTimezone: 'Asia/Kolkata',
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('journey_metric_current_streak')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    final title = tester.widget<Text>(
      find.text('Current consistency streak').first,
    );
    expect(title.maxLines, isNull);
    expect(title.overflow, isNot(TextOverflow.ellipsis));
  });

  test('method rules and annual filtering mirror iOS', () {
    expect(FastingMethod.allowedFor(ObservanceStatus.observed), [
      FastingMethod.fullFast,
      FastingMethod.waterOnly,
      FastingMethod.fruitsMilk,
    ]);
    expect(FastingMethod.allowedFor(ObservanceStatus.partial), [
      FastingMethod.oneMeal,
    ]);
    expect(
      FastingMethod.normalized(
        FastingMethod.fruitsMilk,
        ObservanceStatus.partial,
      ),
      FastingMethod.oneMeal,
    );
    expect(
      FastingMethod.normalized(
        FastingMethod.oneMeal,
        ObservanceStatus.observed,
      ),
      FastingMethod.fullFast,
    );
    expect(
      FastingMethod.normalized(FastingMethod.other, ObservanceStatus.missed),
      isNull,
    );
    final badges = JourneyBadgeCatalog.all([2026, 2027]);
    final selected = badges.where((b) => b.isVisibleInYear(2026));
    expect(selected.any((b) => b.id == 'first_vrat'), isTrue);
    expect(selected.any((b) => b.year == 2027), isFalse);
    expect(badges.where((b) => b.isVisibleInYear(null)).length, badges.length);
  });

  testWidgets('overview uses the share gradient and bright primary action', (
    tester,
  ) async {
    final summary = JourneyRewards.calculate(
      occurrences: [],
      history: [],
      completeYears: {},
    );
    await host(
      tester,
      SingleChildScrollView(
        child: JourneyOverviewPanel(summary: summary, year: 2026),
      ),
    );
    expect(
      tester.widget(find.byKey(const Key('journey_share_year'))),
      isA<FilledButton>(),
    );
    final surface = tester.widget<Container>(
      find.byKey(const Key('journey_overview_surface')),
    );
    final gradient =
        (surface.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors, const [
      Color.fromRGBO(5, 46, 46, 1),
      Color.fromRGBO(8, 20, 33, 1),
    ]);
  });

  testWidgets(
    'year filter applies across tabs and combines all-year statistics',
    (tester) async {
      await host(
        tester,
        VratTrackerScreen(
          ekadashiList: [
            ...journeyEvents(2026),
            ...journeyEvents(2027, extra: true),
          ],
          currentTimezone: 'Asia/Kolkata',
        ),
      );
      await tester.tap(find.byKey(const Key('journey_tab_achievements')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('journey_achievements_year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2027').last);
      await tester.pumpAndSettle();
      final annual = find.byKey(const Key('journey_badge_filter_annual'));
      await tester.ensureVisible(annual);
      await tester.tap(annual);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('journey_badge_journey_2027_q1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('journey_badge_journey_2026_q1')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('journey_achievements_year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All years').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('journey_tab_statistics')));
      await tester.pumpAndSettle();
      expect(find.text('Year:'), findsNothing);
      expect(find.text('0 of 49 Ekadashis'), findsOneWidget);
    },
  );

  for (final glass in [false, true]) {
    for (final code in ['en', 'hi', 'ta', 'te', 'gu', 'bn']) {
      testWidgets(
        '$code status labels fit one row at 320px and large text, Glass=$glass',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final event = journeyEvents(2026).first;
          await host(
            tester,
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: RecordVratDialog(
                ekadashi: event,
                allOccurrences: [event],
                currentTimezone: 'Asia/Kolkata',
              ),
            ),
            code: code,
            glass: glass,
          );
          final positions = <double>[];
          for (final status in ['observed', 'partial', 'missed']) {
            final choice = find.byKey(Key('vrat_status_$status'));
            positions.add(tester.getCenter(choice).dy);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: choice, matching: find.byType(RichText)).last,
            );
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          expect(positions, everyElement(closeTo(positions.first, 0.001)));
          expect(
            tester
                .widget<GlassChip>(find.byKey(const Key('vrat_method_oneMeal')))
                .onTap,
            isNull,
          );
          expect(
            tester
                .widget<GlassChip>(find.byKey(const Key('vrat_method_other')))
                .onTap,
            isNull,
          );
          await tester.tap(find.byKey(const Key('vrat_status_partial')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<GlassChip>(find.byKey(const Key('vrat_method_oneMeal')))
                .onTap,
            isNotNull,
          );
          expect(
            tester
                .widget<GlassChip>(find.byKey(const Key('vrat_method_oneMeal')))
                .selected,
            isTrue,
          );
          for (final method in [
            'fullFast',
            'waterOnly',
            'fruitsMilk',
            'other',
          ]) {
            expect(
              tester
                  .widget<GlassChip>(find.byKey(Key('vrat_method_$method')))
                  .onTap,
              isNull,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('all shared card corners are opaque green pixels', (
    tester,
  ) async {
    final boundary = GlobalKey();
    final p = JourneyRewards.calculate(
      occurrences: [],
      history: [],
      completeYears: {},
    ).year(2026);
    await host(
      tester,
      Center(
        child: RepaintBoundary(
          key: boundary,
          child: SizedBox(
            width: 300,
            child: JourneyAnnualShareCard(progress: p, badges: const []),
          ),
        ),
      ),
    );
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => render.toImage()))!;
    final data = (await tester.runAsync(() => image.toByteData()))!;
    final bytes = data.buffer.asUint8List();
    for (final index in [
      0,
      image.width - 1,
      image.width * (image.height - 1),
      image.width * image.height - 1,
    ]) {
      expect(bytes[index * 4 + 3], 255);
      expect(bytes[index * 4 + 1], greaterThan(bytes[index * 4]));
    }
    image.dispose();
  });
}
