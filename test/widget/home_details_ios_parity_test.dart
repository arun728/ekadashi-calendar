import 'package:ekadashi_calendar/l10n/app_language.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/vrat_recording.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import 'package:ekadashi_calendar/widgets/app_background.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/app_harness.dart';

/// Home and Ekadashi Details match the iOS app (TodayView.swift,
/// EkadashiDetailsView.swift, VratStatusStyle.swift).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppHarness harness;

  setUp(() async {
    harness = AppHarness();
    await harness.install(preferences: {'vrat_tracker_enabled': true});
  });
  tearDown(() => harness.uninstall());

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
  }

  TextStyle styleOf(WidgetTester tester, Finder text) =>
      tester.widget<Text>(text).style ?? const TextStyle();

  /// The Ekadashis on Home and the index of the card on screen.
  (List<EkadashiDate>, int) homeCards(WidgetTester tester) {
    final list = EkadashiService().getEkadashis(
      timezone: 'IST',
      languageCode: 'en',
    );
    final indicator = tester
        .widget<Text>(find.byKey(const Key('home_page_indicator')))
        .data!;
    return (list, int.parse(indicator.split(' / ').first) - 1);
  }

  Color? iconColor(WidgetTester tester, Finder within, IconData icon) =>
      tester
          .widget<Icon>(
            find.descendant(of: within, matching: find.byIcon(icon)),
          )
          .color;

  group('Home header', () {
    testWidgets('located: location.fill arrow, subheadline medium, refresh', (
      tester,
    ) async {
      await pumpHome(tester);
      final tube = find.byKey(const Key('home_options_tube'));
      expect(
        find.descendant(of: tube, matching: find.byIcon(Icons.near_me)),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_on), findsNothing);
      final label = find.text('Chennai • IST');
      expect(styleOf(tester, label).fontSize, IosText.subheadline);
      expect(styleOf(tester, label).fontWeight, FontWeight.w500);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.refresh)).size,
        IosText.caption2,
      );
      // Tapping the city looks the location up again.
      final before = harness.locationCalls
          .where((c) => c.method == 'getCurrentLocation')
          .length;
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(
        harness.locationCalls
            .where((c) => c.method == 'getCurrentLocation')
            .length,
        greaterThan(before),
      );
    });

    testWidgets(
      'locating: "Locating... • zone", tappable to ask for location again',
      (tester) async {
        harness.gpsAvailable = false;
        harness.deviceTimezone = 'America/New_York';
        await pumpHome(tester);
        final chip = find.textContaining(RegExp(r'^Locating\.\.\. • \S'));
        expect(chip, findsOneWidget);
        expect(styleOf(tester, chip).fontSize, IosText.subheadline);
        expect(
          find.descendant(
            of: find.byKey(const Key('home_options_tube')),
            matching: find.byIcon(Icons.near_me),
          ),
          findsOneWidget,
        );
        final asked = harness.locationCalls
            .where((c) => c.method == 'requestLocationPermission')
            .length;
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(
          harness.locationCalls
              .where((c) => c.method == 'requestLocationPermission')
              .length,
          asked + 1,
        );
      },
    );

    testWidgets('denied: iOS orange, location.slash, subheadline underlined', (
      tester,
    ) async {
      harness.locationGranted = false;
      await pumpHome(tester);
      final label = find.text('Location Denied');
      final context = tester.element(label);
      expect(styleOf(tester, label).color, IosColors.orange(context));
      expect(styleOf(tester, label).fontSize, IosText.subheadline);
      expect(styleOf(tester, label).decoration, TextDecoration.underline);
      expect(find.byIcon(Icons.near_me_disabled), findsOneWidget);
    });

    testWidgets('language menu: checkmark leading, globe teal', (tester) async {
      await pumpHome(tester);
      final menu = find.byKey(const Key('language_menu'));
      expect(
        iconColor(tester, menu, Icons.language),
        IosColors.teal,
      );
      expect(
        styleOf(
          tester,
          find.descendant(of: menu, matching: find.text('English')),
        ).fontSize,
        IosText.subheadline,
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final check = find.byIcon(Icons.check);
      expect(check, findsOneWidget);
      final english = find.text(AppLanguage.named('en').nativeName).last;
      expect(
        tester.getCenter(check).dx,
        lessThan(tester.getTopLeft(english).dx),
      );
    });
  });

  group('Home card', () {
    testWidgets('glass card radius 24, iOS text sizes, labelled arrows', (
      tester,
    ) async {
      await pumpHome(tester);
      final card = find.byKey(const Key('home_ekadashi_card'));
      expect(card, findsOneWidget);
      expect(tester.widget(card), isA<GlassPanel>());
      expect(tester.widget<GlassPanel>(card).radius, 24);
      final (list, index) = homeCards(tester);
      final event = list[index];
      final name = find.descendant(of: card, matching: find.text(event.name));
      expect(styleOf(tester, name).fontSize, IosText.title);
      expect(styleOf(tester, name).fontWeight, FontWeight.bold);
      final description = find.descendant(
        of: card,
        matching: find.text(event.description),
      );
      expect(styleOf(tester, description).fontSize, IosText.callout);
      expect(styleOf(tester, description).fontStyle, FontStyle.italic);
      expect(
        styleOf(tester, find.byKey(const Key('home_page_indicator'))).fontSize,
        IosText.footnote,
      );
      // Arrows are read out as the Ekadashi they go to.
      expect(
        tester.getSemantics(find.byKey(const Key('home_next'))),
        containsSemantics(label: list[index + 1].name),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('home_previous'))),
        containsSemantics(label: list[index - 1].name),
      );
    });

    testWidgets('View Details is the prominent teal capsule, white text', (
      tester,
    ) async {
      await pumpHome(tester);
      final button = find.byKey(const Key('view_details'));
      expect(tester.widget(button), isA<FilledButton>());
      final style = tester.widget<FilledButton>(button).style!;
      expect(style.backgroundColor!.resolve({}), IosColors.teal);
      expect(style.shape!.resolve({}), isA<StadiumBorder>());
      final label = find.descendant(of: button, matching: find.byType(Text));
      expect(styleOf(tester, label).fontSize, IosText.callout);
      expect(styleOf(tester, label).fontWeight, FontWeight.bold);
      expect(
        tester.widget<FilledButton>(button).style!.foregroundColor!.resolve(
          {},
        ),
        Colors.white,
      );
    });

    testWidgets('Record: glass capsule, calendar.badge.plus, dimmed when '
        'closed, teal when open', (tester) async {
      await pumpHome(tester);
      // The card after the next one is in the future: closed.
      await tester.tap(find.byKey(const Key('home_next')));
      await tester.pumpAndSettle();
      var record = find.byKey(const Key('home_record_vrat'));
      expect(tester.widget(record), isA<OutlinedButton>());
      expect(tester.widget<OutlinedButton>(record).onPressed, isNull);
      expect(
        tester.widget<OutlinedButton>(record).style!.shape!.resolve({}),
        isA<StadiumBorder>(),
      );
      final context = tester.element(record);
      expect(
        iconColor(tester, record, Icons.calendar_today_outlined),
        IosColors.tertiary(context),
      );
      expect(
        find.descendant(of: record, matching: find.byIcon(Icons.add_circle)),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(record),
        containsSemantics(hint: 'You can record this fast once Parana begins'),
      );
      // Two cards back is a passed Ekadashi: open.
      await tester.tap(find.byKey(const Key('home_previous')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_previous')));
      await tester.pumpAndSettle();
      final (list, index) = homeCards(tester);
      expect(
        VratRecording.isOpen(
          list[index],
          now: DateTime.now(),
          timezone: 'IST',
        ),
        isTrue,
      );
      record = find.byKey(const Key('home_record_vrat'));
      expect(tester.widget<OutlinedButton>(record).onPressed, isNotNull);
      expect(
        iconColor(tester, record, Icons.calendar_today_outlined),
        IosColors.teal,
      );
    });

    testWidgets('empty: header tube stays, unavailable view with symbol', (
      tester,
    ) async {
      // No published timings for this zone: no Ekadashi to show.
      harness.timezone = 'Antarctica/Troll';
      await pumpHome(tester);
      expect(find.byKey(const Key('home_options_tube')), findsOneWidget);
      final empty = find.byKey(const Key('home_empty'));
      expect(tester.widget(empty), isA<UnavailableView>());
      expect(
        tester.widget<UnavailableView>(empty).icon,
        Icons.event_busy_outlined,
      );
      expect(
        tester.widget<UnavailableView>(empty).title,
        'No Ekadashi on this day',
      );
    });
  });

  group('Details', () {
    Future<void> openDetails(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('view_details')));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsScreen), findsOneWidget);
    }

    testWidgets('pushed inside the Home tab: background, bar, tab bar', (
      tester,
    ) async {
      await pumpHome(tester);
      await openDetails(tester);
      final details = find.byType(DetailsScreen);
      expect(
        find.descendant(of: details, matching: find.byType(AppBackground)),
        findsOneWidget,
      );
      // The tab bar stays; the shell's search button does not.
      expect(find.byKey(const Key('glass_tab_0')).hitTestable(), findsOne);
      expect(
        find.byKey(const Key('open_global_search')).hitTestable(),
        findsNothing,
      );
      expect(
        find.descendant(of: details, matching: find.byType(BackButton)),
        findsOneWidget,
      );
      // The last element scrolls clear of the floating tab bar.
      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: details,
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(
        (scroll.padding! as EdgeInsets).bottom,
        greaterThanOrEqualTo(100),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsScreen), findsNothing);
      expect(find.byKey(const Key('home_ekadashi_card')), findsOneWidget);
    });

    testWidgets('iOS sizes, time-zone pill, glass timings box', (
      tester,
    ) async {
      await pumpHome(tester);
      final (list, index) = homeCards(tester);
      final event = list[index];
      await openDetails(tester);
      final details = find.byType(DetailsScreen);
      final name = find.descendant(of: details, matching: find.text(event.name));
      expect(styleOf(tester, name).fontSize, IosText.largeTitle);
      final pill = find.descendant(of: details, matching: find.byType(StatusPill));
      expect(pill, findsOneWidget);
      expect(tester.widget<StatusPill>(pill).text, 'IST');
      final section = find.text('Significance');
      expect(styleOf(tester, section).fontSize, IosText.title3);
      expect(
        styleOf(
          tester,
          find.descendant(of: details, matching: find.text(event.description)),
        ).fontSize,
        IosText.body,
      );
      final box = find.byKey(const Key('details_timings'));
      expect(tester.widget(box), isA<GlassPanel>());
      expect(tester.widget<GlassPanel>(box).radius, 16);
      expect(tester.widget<GlassPanel>(box).tint, IosColors.teal);
      expect(
        find.descendant(of: box, matching: find.byIcon(Icons.restaurant)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: box, matching: find.text('Start Fasting')),
        findsOneWidget,
      );
    });

    testWidgets('closed: dimmed button reads "once Parana begins"', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_next')));
      await tester.pumpAndSettle();
      await openDetails(tester);
      final button = find.byKey(const Key('details_record_vrat'));
      await tester.ensureVisible(button);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        tester.widget<OutlinedButton>(button).style!.shape!.resolve({}),
        isA<StadiumBorder>(),
      );
      expect(
        find.descendant(
          of: button,
          matching: find.text('You can record this fast once Parana begins'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.help_outline)),
        findsOneWidget,
      );
      // Dimmed: the whole button is drawn faded.
      expect(
        find.ancestor(of: button, matching: find.byType(Opacity)),
        findsWidgets,
      );
      final opacity = tester
          .widgetList<Opacity>(
            find.ancestor(of: button, matching: find.byType(Opacity)),
          )
          .first
          .opacity;
      expect(opacity, lessThan(1));
    });

    testWidgets('open: grey questionmark Record Vrat; observed: green check', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('home_previous')));
      await tester.pumpAndSettle();
      final (list, index) = homeCards(tester);
      final event = list[index];
      await openDetails(tester);
      final button = find.byKey(const Key('details_record_vrat'));
      await tester.ensureVisible(button);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      expect(
        find.descendant(of: button, matching: find.text('Record Vrat')),
        findsOneWidget,
      );
      final context = tester.element(button);
      expect(
        iconColor(tester, button, Icons.help_outline),
        IosColors.gray(context),
      );
      final tracker = Provider.of<VratTrackerService>(context, listen: false);
      await tester.runAsync(
        () => tracker.recordVrat(
          ekadashiOccurrenceId: event.id,
          occurrenceUid: event.occurrenceUid,
          ekadashiDate: event.date.toIso8601String().substring(0, 10),
          ekadashiName: event.name,
          status: ObservanceStatus.observed,
          timezone: 'IST',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: button, matching: find.text('Vrat: Observed')),
        findsOneWidget,
      );
      expect(
        iconColor(tester, button, Icons.check_circle_outline),
        IosColors.green(context),
      );
      // Home shows the filled check for an observed fast.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final record = find.byKey(const Key('home_record_vrat'));
      expect(
        find.descendant(of: record, matching: find.byIcon(Icons.check_circle)),
        findsOneWidget,
      );
    });
  });
}
