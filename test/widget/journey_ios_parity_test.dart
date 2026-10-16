import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'dart:async';

import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/achievement_unlock_dialog.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/record_vrat_dialog.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/vrat_tracker_screen.dart';
import 'package:ekadashi_calendar/services/achievement_evaluator.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/widgets/glass_tube.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/premium_fixture.dart';

/// The Journey tab, its record sheet and the achievement unlock follow the
/// iOS app (ios-native Features/Vrat: VratView, RecordVratSheet,
/// AchievementUnlockView, VratStatusStyle).
final _year = DateTime.now().year;

EkadashiDate _event(int id, DateTime date) => EkadashiDate(
  id: id,
  name: 'Parity Ekadashi $id',
  date: date,
  fastStartTime: '06:00 AM',
  fastBreakTime: '06:00 AM - 08:00 AM',
  description: '',
);

/// Three past Ekadashis of this year and one far in the future.
final _events = [
  _event(1, DateTime(_year, 1, 2)),
  _event(2, DateTime(_year, 2, 2)),
  _event(3, DateTime(_year, 3, 2)),
  _event(4, DateTime(_year, 12, 30).add(const Duration(days: 400))),
];

Future<void> _record(
  VratTrackerService tracker,
  EkadashiDate e, [
  ObservanceStatus status = ObservanceStatus.observed,
]) => tracker.recordVrat(
  ekadashiOccurrenceId: e.id,
  occurrenceUid: e.occurrenceUid,
  ekadashiDate: e.date.toIso8601String().substring(0, 10),
  ekadashiName: e.name,
  status: status,
  occurrences: _events,
);

/// A tracker whose saves wait for [gate], so "saving" can be observed.
class _SlowTracker extends VratTrackerService {
  final gate = Completer<void>();
  @override
  Future<List<Achievement>> recordVrat({
    required int ekadashiOccurrenceId,
    String? occurrenceUid,
    required String ekadashiDate,
    required String ekadashiName,
    required ObservanceStatus status,
    FastingMethod? fastingMethod,
    String? fastingMethodOther,
    String? note,
    String? tradition,
    String? timezone,
    List<EkadashiDate>? occurrences,
  }) async {
    await gate.future;
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<VratTrackerService> pumpJourney(
    WidgetTester tester, {
    VratTrackerService? tracker,
    PremiumService? premium,
    Size size = const Size(393, 852),
    Brightness brightness = Brightness.light,
    List<EkadashiDate>? events,
  }) async {
    final list = events ?? _events;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = tracker ?? VratTrackerService();
    if (!service.isInitialized) {
      await tester.runAsync(() => service.init(occurrences: list));
    }
    final billing = premium == null ? null : FixtureBilling(premium);
    if (billing != null) addTearDown(billing.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: service),
          ChangeNotifierProvider(create: (_) => LanguageService()),
          if (premium != null) ChangeNotifierProvider.value(value: premium),
          if (billing != null)
            ChangeNotifierProvider<PlayBillingService>.value(value: billing),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: VratTrackerScreen(ekadashiList: list, currentTimezone: 'IST'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> openSection(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.byKey(Key('journey_tab_$name')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('journey_tab_$name')));
    await tester.pumpAndSettle();
  }

  /// Lets a toast finish its four seconds.
  Future<void> drainToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  group('Statistics', () {
    testWidgets('a 130 progress ring with a whole percentage, then one grid '
        'of six equal glass tiles', (tester) async {
      final tracker = VratTrackerService();
      await tester.runAsync(() => tracker.init(occurrences: _events));
      await tester.runAsync(() => _record(tracker, _events[0]));
      await tester.runAsync(() => _record(tracker, _events[1]));
      await pumpJourney(tester, tracker: tracker);
      await openSection(tester, 'statistics');

      final ring = find.byKey(const Key('journey_stats_ring'));
      expect(ring, findsOneWidget);
      expect(tester.getSize(ring), const Size(130, 130));
      expect(
        find.descendant(of: ring, matching: find.text('67%')),
        findsOneWidget,
      );
      expect(find.text('66.7%'), findsNothing);
      expect(find.byType(DropdownButton<int>), findsNothing);

      const tiles = [
        'observed',
        'partial',
        'missed',
        'unrecorded',
        'current_streak',
        'longest_streak',
      ];
      final sizes = <Size>[];
      final origins = <Offset>[];
      for (final name in tiles) {
        final tile = find.byKey(Key('journey_stat_$name'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        expect(tile, findsOneWidget, reason: name);
        expect(tester.widget(tile), isA<GlassPanel>(), reason: name);
        sizes.add(tester.getSize(tile));
        origins.add(tester.getTopLeft(tile));
      }
      expect(sizes.toSet(), hasLength(1), reason: 'six equal tiles');
      // Two columns, three rows, in the iOS order.
      for (var row = 0; row < 3; row++) {
        expect(origins[row * 2].dy, origins[row * 2 + 1].dy);
        expect(origins[row * 2].dx, lessThan(origins[row * 2 + 1].dx));
      }
      expect(origins[2].dy, greaterThan(origins[0].dy));
      expect(origins[4].dy, greaterThan(origins[2].dy));

      // Values take the status colours (observed is the system green).
      final context = tester.element(ring);
      Color valueColor(String name, String value) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key('journey_stat_$name')),
              matching: find.text(value),
            ),
          )
          .style!
          .color!;
      expect(valueColor('observed', '2'), IosColors.green(context));
      expect(valueColor('unrecorded', '1'), IosColors.gray(context));
      expect(valueColor('missed', '0'), IosColors.missed);
      expect(valueColor('partial', '0'), IosColors.partial);

      // Year menu: a glass capsule with a calendar icon.
      final menu = find.byKey(const Key('journey_stats_year_menu'));
      expect(menu, findsOneWidget);
      expect(
        find.descendant(of: menu, matching: find.text('$_year')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.byIcon(AppIcons.journeyYear)),
        findsOneWidget,
      );
    });
  });

  group('History', () {
    testWidgets('glass year menu, status-coloured chips without checkmarks, '
        'centred instruction and no divider', (tester) async {
      await pumpJourney(tester);
      await openSection(tester, 'history');
      final menu = find.byKey(const Key('journey_history_year_menu'));
      expect(menu, findsOneWidget);
      expect(
        find.descendant(of: menu, matching: find.text('$_year')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.byIcon(AppIcons.journeyYear)),
        findsOneWidget,
      );
      expect(find.byType(DropdownButton<int>), findsNothing);
      expect(find.byType(GlassFilterChip), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(Divider), findsNothing);

      final context = tester.element(menu);
      final expected = {
        'all': IosColors.teal,
        'observed': IosColors.green(context),
        'partial': IosColors.partial,
        'missed': IosColors.missed,
        'unrecorded': IosColors.gray(context),
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        final chip = find.byKey(Key('journey_filter_$key'));
        expect(chip, findsOneWidget, reason: key);
        expect(tester.widget<GlassChip>(chip).color, value, reason: key);
      }
      expect(
        tester.widget<GlassChip>(find.byKey(const Key('journey_filter_all'))),
        isA<GlassChip>().having((c) => c.selected, 'selected', isTrue),
      );

      final instruction = tester.widget<Text>(
        find.text(LanguageService().translate('tap_to_record_instruction')),
      );
      expect(instruction.textAlign, TextAlign.center);
      expect(instruction.style?.fontSize, IosText.caption);
    });

    testWidgets('an empty filter shows the leaf empty state', (tester) async {
      await pumpJourney(tester);
      await openSection(tester, 'history');
      await tester.ensureVisible(
        find.byKey(const Key('journey_filter_missed')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('journey_filter_missed')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GlassChip>(find.byKey(const Key('journey_filter_missed')))
            .selected,
        isTrue,
      );
      final empty = find.byType(UnavailableView);
      expect(empty, findsOneWidget);
      expect(tester.widget<UnavailableView>(empty).icon, AppIcons.journeyEmpty);
    });

    testWidgets('rows are glass panels with the pill and chevron side by side '
        'and a clock until the fast can be recorded', (tester) async {
      final tracker = VratTrackerService();
      await tester.runAsync(() => tracker.init(occurrences: _events));
      await tester.runAsync(() => _record(tracker, _events[0]));
      await pumpJourney(tester, tracker: tracker);
      await openSection(tester, 'history');

      final row = find.byKey(Key('journey_row_${_events[0].occurrenceUid}'));
      expect(row, findsOneWidget);
      final panel = tester.widget<GlassPanel>(row);
      expect(panel.radius, 14);
      final pill = find.descendant(of: row, matching: find.byType(StatusPill));
      expect(pill, findsOneWidget);
      final context = tester.element(row);
      expect(tester.widget<StatusPill>(pill).color, IosColors.green(context));
      final chevron = find.descendant(
        of: row,
        matching: find.byIcon(AppIcons.rowDisclosure),
      );
      expect(chevron, findsOneWidget);
      expect(
        (tester.getCenter(pill).dy - tester.getCenter(chevron).dy).abs(),
        lessThan(2),
        reason: 'pill and chevron share one line',
      );
      expect(
        tester.getCenter(chevron).dx,
        greaterThan(tester.getCenter(pill).dx),
      );
      final name = tester.widget<Text>(
        find.descendant(of: row, matching: find.text(_events[0].name)),
      );
      expect(name.style?.fontSize, IosText.headline);

      // The future Ekadashi (a later year, chosen in the year menu): a
      // clock, no chevron, and a toast when tapped.
      await tester.tap(find.byKey(const Key('journey_history_year_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${_events[3].date.year}').last);
      await tester.pumpAndSettle();
      final future = find.byKey(Key('journey_row_${_events[3].occurrenceUid}'));
      await tester.ensureVisible(future);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: future,
          matching: find.byIcon(AppIcons.journeyPending),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: future,
          matching: find.byIcon(AppIcons.rowDisclosure),
        ),
        findsNothing,
      );
      await tester.tap(future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('app_toast')), findsOneWidget);
      expect(
        find.text(LanguageService().translate('journey_record_after_parana')),
        findsOneWidget,
      );
      expect(find.byType(RecordVratDialog), findsNothing);
      await drainToast(tester);
    });
  });

  group('Achievements', () {
    testWidgets('intro and the glass Premium button scroll with an adaptive '
        'grid of top-aligned glass cards without glow', (tester) async {
      final premium = PremiumService(
        entitlements: PremiumFixture()..premium = false,
      );
      addTearDown(premium.dispose);
      final tracker = VratTrackerService();
      await tester.runAsync(() => tracker.init(occurrences: _events));
      await tester.runAsync(() => _record(tracker, _events[0]));
      await pumpJourney(
        tester,
        tracker: tracker,
        premium: premium,
        size: const Size(600, 900),
      );
      await openSection(tester, 'achievements');

      final button = find.byKey(const Key('journey_more_achievements'));
      expect(button, findsOneWidget);
      expect(tester.widget(button), isA<OutlinedButton>());
      final card = find.byKey(const Key('journey_achievement_first_vrat'));
      expect(card, findsOneWidget);
      expect(tester.widget(card), isA<GlassPanel>());
      // One scroll view holds the intro, the button and the grid.
      Scrollable scrollOf(Finder f) => tester.widget<Scrollable>(
        find.ancestor(of: f, matching: find.byType(Scrollable)).first,
      );
      expect(identical(scrollOf(button), scrollOf(card)), isTrue);
      expect(
        identical(
          scrollOf(
            find.text(LanguageService().translate('premium_free_achievements')),
          ),
          scrollOf(card),
        ),
        isTrue,
      );

      // Adaptive columns of at least 150: three across 600 points.
      final tops = [
        for (final a in AchievementEvaluator.allAchievements.take(3))
          tester.getTopLeft(find.byKey(Key('journey_achievement_${a.id}'))).dy,
      ];
      expect(tops.toSet(), hasLength(1));

      // Top-aligned content: the badge sits 14 below the card's top.
      final badge = find.descendant(
        of: card,
        matching: find.byIcon(AppIcons.achievementFirst),
      );
      expect(badge, findsOneWidget, reason: 'first_vrat is a leaf, as iOS');
      final circleTop = tester
          .getTopLeft(
            find.ancestor(of: badge, matching: find.byType(Container)).first,
          )
          .dy;
      expect(circleTop - tester.getTopLeft(card).dy, closeTo(14, .5));

      // No glow.
      final shadows = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(VratTrackerScreen),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);
      expect(shadows, isEmpty);
    });

    test('first_vrat is a leaf and full_year a sun, as the iOS badges', () {
      final icons = {
        for (final a in AchievementEvaluator.allAchievements) a.id: a.icon,
      };
      expect(icons['first_vrat'], AppIcons.achievementFirst);
      expect(icons['full_year_observance'], AppIcons.achievementFullYear);
    });
  });

  group('Record sheet', () {
    testWidgets('an iOS sheet with Cancel, status-coloured chips with icons, '
        'glass method chips, growing notes and a capsule save', (tester) async {
      await pumpJourney(tester);
      await openSection(tester, 'history');
      await tester.tap(find.text(_events[1].name).hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(RecordVratDialog), findsOneWidget);

      final cancel = find.byKey(const Key('vrat_record_cancel'));
      expect(cancel, findsOneWidget);
      expect(tester.widget(cancel), isA<BarTextButton>());
      expect(
        find.descendant(of: cancel, matching: find.text('Cancel')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('vrat_record_delete')), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(RecordVratDialog),
          matching: find.byType(SheetBar),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(RecordVratDialog),
          matching: find.byType(SheetBar),
        ),
        findsOneWidget,
      );

      final context = tester.element(find.byType(RecordVratDialog));
      final statuses = {
        'observed': (IosColors.green(context), AppIcons.statusObserved),
        'partial': (IosColors.partial, AppIcons.statusPartial),
        'missed': (IosColors.missed, AppIcons.statusMissed),
      };
      for (final MapEntry(:key, :value) in statuses.entries) {
        final chip = find.byKey(Key('vrat_status_$key'));
        expect(chip, findsOneWidget, reason: key);
        final widget = tester.widget<GlassChip>(chip);
        expect(widget.color, value.$1, reason: key);
        expect(widget.icon, value.$2, reason: key);
      }
      expect(
        tester
            .widget<GlassChip>(find.byKey(const Key('vrat_status_observed')))
            .selected,
        isTrue,
      );
      // The selected (semibold) label is shown whole, not cut short.
      for (final name in ['observed', 'partial', 'missed']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find
              .descendant(
                of: find.byKey(Key('vrat_status_$name')),
                matching: find.byType(RichText),
              )
              .last,
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: name);
      }

      expect(find.byType(ChoiceChip), findsNothing);
      for (final method in FastingMethod.values) {
        final chip = find.byKey(Key('vrat_method_${method.name}'));
        expect(chip, findsOneWidget, reason: method.name);
        expect(tester.widget(chip), isA<GlassChip>());
      }

      final notes = tester.widget<TextField>(
        find.byKey(const Key('vrat_record_notes')),
      );
      expect(notes.minLines, 3);
      expect(notes.maxLines, 5);

      final form = tester.widget<Column>(
        find.byKey(const Key('vrat_record_form')),
      );
      expect(form.spacing, 20);

      final save = find.byKey(const Key('vrat_record_save'));
      expect(tester.widget(save), isA<FilledButton>());
      final shape = tester.widget<FilledButton>(save).style!.shape!.resolve({});
      expect(shape, isA<StadiumBorder>());

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(RecordVratDialog), findsNothing);
    });

    testWidgets('an existing record shows a red trash in the bar', (
      tester,
    ) async {
      final tracker = VratTrackerService();
      await tester.runAsync(() => tracker.init(occurrences: _events));
      await tester.runAsync(() => _record(tracker, _events[0]));
      await pumpJourney(tester, tracker: tracker);
      await openSection(tester, 'history');
      await tester.tap(find.text(_events[0].name).hitTestable());
      await tester.pumpAndSettle();
      final trash = find.byKey(const Key('vrat_record_delete'));
      expect(trash, findsOneWidget);
      expect(
        find.ancestor(of: trash, matching: find.byType(SheetBar)),
        findsOneWidget,
      );
      final icon = tester.widget<Icon>(
        find.descendant(of: trash, matching: find.byType(Icon)),
      );
      expect(icon.icon, AppIcons.delete);
      expect(icon.color, IosColors.red(tester.element(trash)));
    });

    testWidgets('the save button is disabled while saving', (tester) async {
      final tracker = _SlowTracker();
      await pumpJourney(tester, tracker: tracker);
      await openSection(tester, 'history');
      await tester.tap(find.text(_events[1].name).hitTestable());
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('vrat_record_save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      tracker.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RecordVratDialog), findsNothing);
    });

    testWidgets('the fourth free entry opens the paywall with its reason and '
        'a toast when not bought', (tester) async {
      final premium = PremiumService(
        entitlements: PremiumFixture()..premium = false,
      );
      addTearDown(premium.dispose);
      final tracker = VratTrackerService();
      final past = [
        for (var i = 0; i < 4; i++) _event(10 + i, DateTime(_year, 1, 3 + i)),
      ];
      await tester.runAsync(() => tracker.init(occurrences: past));
      for (final e in past.take(3)) {
        await tester.runAsync(
          () => tracker.recordVrat(
            ekadashiOccurrenceId: e.id,
            occurrenceUid: e.occurrenceUid,
            ekadashiDate: e.date.toIso8601String().substring(0, 10),
            ekadashiName: e.name,
            status: ObservanceStatus.observed,
          ),
        );
      }
      final billing = FixtureBilling(premium);
      addTearDown(billing.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tracker),
            ChangeNotifierProvider(create: (_) => LanguageService()),
            ChangeNotifierProvider.value(value: premium),
            ChangeNotifierProvider<PlayBillingService>.value(value: billing),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => RecordVratDialog.show(
                    context,
                    ekadashi: past[3],
                    allOccurrences: past,
                    currentTimezone: 'IST',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('vrat_record_save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      final paywall = find.byType(PremiumScreen);
      expect(paywall, findsOneWidget);
      expect(
        tester.widget<PremiumScreen>(paywall).reasonKey,
        'vrat_free_limit_reached',
      );
      await tester.tap(find.byKey(const Key('premium_close')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('app_toast')), findsOneWidget);
      expect(tracker.getRecordByUid(past[3].occurrenceUid), isNull);
      await drainToast(tester);
    });
  });

  group('Achievement unlock', () {
    testWidgets('a bottom sheet with a success haptic, uppercase caption, '
        'title 22 and a full-width Hari Om button', (tester) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final achievement = AchievementEvaluator.allAchievements.first;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageService(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      AchievementUnlockDialog.show(context, achievement),
                  child: const Text('show'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
      final sheet = find.byType(AchievementUnlockDialog);
      expect(sheet, findsOneWidget);
      expect(
        find.ancestor(of: sheet, matching: find.byType(BottomSheet)),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(haptics, isNotEmpty, reason: 'success haptic');
      expect(find.text('ACHIEVEMENT UNLOCKED'), findsOneWidget);
      final title = tester.widget<Text>(
        find.text(LanguageService().translate(achievement.titleKey)),
      );
      expect(title.style?.fontSize, IosText.title2);
      final ok = find.byKey(const Key('achievement_unlock_ok'));
      expect(tester.widget(ok), isA<FilledButton>());
      expect(
        find.descendant(of: ok, matching: find.text('Hari Om 🙏')),
        findsOneWidget,
      );
      expect(tester.getSize(ok).width, closeTo(393 - 56, 1));
      await tester.tap(ok);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    });
  });

  group('Overview (iPhone screenshot)', () {
    testWidgets('metric cards are glass panels strongly tinted with their '
        'accent, icon left and value right', (tester) async {
      await pumpJourney(tester, brightness: Brightness.dark);
      final context = tester.element(find.byType(VratTrackerScreen));
      final expected = {
        'current_streak': (IosColors.orange(context), AppIcons.journeyStreak),
        'longest_streak': (IosColors.amber, AppIcons.journeyBest),
        'annual_completion': (IosColors.teal, AppIcons.journeyRate),
        'total_observed': (IosColors.green(context), AppIcons.statusObserved),
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        final card = find.byKey(Key('journey_metric_$key'));
        expect(card, findsOneWidget, reason: key);
        final panel = tester.widget<GlassPanel>(card);
        expect(panel.tint, value.$1, reason: key);
        // iOS Glass.tint(color.opacity(0.35)).
        expect(panel.tintOpacity, .35, reason: key);
        final icon = find.descendant(of: card, matching: find.byIcon(value.$2));
        expect(icon, findsOneWidget, reason: key);
        expect(tester.widget<Icon>(icon).color, value.$1, reason: key);
        final cardRect = tester.getRect(card);
        expect(
          tester.getCenter(icon).dx,
          lessThan(cardRect.center.dx),
          reason: '$key icon top-left',
        );
        // The value sits at the top-right corner (16 padding).
        final valueText = find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontSize == IosText.title2,
          ),
        );
        expect(
          tester.getRect(valueText).right,
          closeTo(cardRect.right - 16, 1),
          reason: '$key value top-right',
        );
      }
      // Two by two: streaks on the first row, completion and total below.
      final a = tester.getTopLeft(
        find.byKey(const Key('journey_metric_current_streak')),
      );
      final b = tester.getTopLeft(
        find.byKey(const Key('journey_metric_longest_streak')),
      );
      final c = tester.getTopLeft(
        find.byKey(const Key('journey_metric_annual_completion')),
      );
      expect(a.dy, b.dy);
      expect(c.dy, greaterThan(a.dy));
    });

    // The shared default is the iOS glass tint (.35, Glass.swift).
    test('GlassPanel tints at the iOS strength by default', () {
      const panel = GlassPanel(tint: IosColors.teal, child: SizedBox());
      expect(panel.tintOpacity, .35);
    });

    testWidgets('a GlassPanel paints its tint at tintOpacity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassPanel(
            tint: IosColors.teal,
            tintOpacity: .35,
            child: SizedBox(width: 50, height: 50),
          ),
        ),
      );
      final tinted = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color != null);
      expect(
        tinted.map((d) => d.color),
        contains(IosColors.teal.withValues(alpha: .35)),
      );
    });

    testWidgets('recent rows show a grey Not Recorded pill and a green '
        'Observed pill, each beside its chevron', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final recent = [
        _event(21, today.subtract(const Duration(days: 20))),
        _event(22, today.subtract(const Duration(days: 6))),
      ];
      final tracker = VratTrackerService();
      await tester.runAsync(() => tracker.init(occurrences: recent));
      await tester.runAsync(
        () => tracker.recordVrat(
          ekadashiOccurrenceId: recent[1].id,
          occurrenceUid: recent[1].occurrenceUid,
          ekadashiDate: recent[1].date.toIso8601String().substring(0, 10),
          ekadashiName: recent[1].name,
          status: ObservanceStatus.observed,
          occurrences: recent,
        ),
      );
      await pumpJourney(
        tester,
        tracker: tracker,
        events: recent,
        brightness: Brightness.dark,
      );
      final context = tester.element(find.byType(VratTrackerScreen));
      for (final (event, label, color, icon) in [
        (
          recent[0],
          'Not Recorded',
          IosColors.gray(context),
          AppIcons.statusUnrecorded,
        ),
        (
          recent[1],
          'Observed',
          IosColors.green(context),
          AppIcons.statusObserved,
        ),
      ]) {
        final row = find.byKey(Key('journey_row_${event.occurrenceUid}'));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final pill = find.descendant(
          of: row,
          matching: find.byType(StatusPill),
        );
        expect(tester.widget<StatusPill>(pill).text, label);
        expect(tester.widget<StatusPill>(pill).color, color);
        final status = find.descendant(of: row, matching: find.byIcon(icon));
        expect(tester.widget<Icon>(status).color, color);
        final chevron = find.descendant(
          of: row,
          matching: find.byIcon(AppIcons.rowDisclosure),
        );
        expect(
          (tester.getCenter(pill).dy - tester.getCenter(chevron).dy).abs(),
          lessThan(2),
        );
      }
    });
  });

  testWidgets('a storage error shows the iOS unavailable view with a '
      'prominent retry', (tester) async {
    final tracker = VratTrackerService();
    await tester.runAsync(() => tracker.init(occurrences: _events));
    tracker.storageError = 'broken';
    await pumpJourney(tester, tracker: tracker);
    final view = find.byType(UnavailableView);
    expect(view, findsOneWidget);
    expect(find.text('broken'), findsOneWidget);
    expect(
      find.descendant(of: view, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
  });
}
