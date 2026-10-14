import 'package:ekadashi_calendar/screens/panchang_pages.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/panchang/observance_calendar_service.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_city.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_engine.dart';
import 'package:ekadashi_calendar/services/panchang/panchang_location_store.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/search/search_catalog.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:ekadashi_calendar/widgets/tab_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../support/premium_fixture.dart';

/// The Android Panchang follows the iOS PanchangView element by element
/// (ios-native Features/Panchang): toolbar items, glass location pill and
/// date stepper, iOS sheets, glass chips, card and row typography, colours.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = EkadashiService();

  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting();
    await service.initializeData();
    // Read from disk now: assets never load on the widget tests' fake clock.
    await PanchangLocationStore.cities();
    ObservanceCalendarService.calculateInline = true;
    ObservanceCalendarService.instance.put(
      2026,
      PanchangCity.newDelhi,
      const PanchangEngine().observanceCalendar(
        2026,
        city: PanchangCity.newDelhi,
      ),
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PremiumService> premiumService(bool active) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()..premium = active,
    );
    if (active) await premium.refresh();
    return premium;
  }

  /// The Panchang tab under a top bar fed by its [TabBarSlots], as the
  /// app shell does.
  Future<TabBarSlots> show(
    WidgetTester tester, {
    required PremiumService premium,
    DateTime? date,
    PanchangCity? city = PanchangCity.newDelhi,
    PanchangLocationStore? store,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final slots = TabBarSlots();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PremiumService>.value(value: premium),
          ChangeNotifierProvider<LanguageService>.value(
            value: LanguageService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: ListenableBuilder(
                listenable: slots,
                builder: (context, _) => AppBar(
                  key: const Key('test_top_bar'),
                  leadingWidth: 120,
                  leading: slots.leading(context),
                  actions: slots.actions(context),
                ),
              ),
            ),
            body: PanchangScreen(
              barSlots: slots,
              initialDate: date,
              initialCity: city,
              locationStore: store,
              ekadashiList: service.getEkadashis(
                timezone: 'IST',
                languageCode: 'en',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return slots;
  }

  Finder inBar(Finder finder) => find.descendant(
    of: find.byKey(const Key('test_top_bar')),
    matching: finder,
  );
  Finder inPage(Finder finder) => find.descendant(
    of: find.byKey(const Key('panchang_scroll_view')),
    matching: finder,
  );

  GlassPanel panelAround(WidgetTester tester, Finder child) =>
      tester.widget<GlassPanel>(
        find.ancestor(of: child, matching: find.byType(GlassPanel)).first,
      );

  TextStyle styleOf(WidgetTester tester, Finder text) =>
      tester.widget<Text>(text).style ?? const TextStyle();

  testWidgets('Today and the calculation notes live in the top bar', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 10, 8));
    expect(inBar(find.byKey(const Key('panchang_today'))), findsOneWidget);
    expect(inBar(find.byKey(const Key('panchang_notes'))), findsOneWidget);
    expect(inPage(find.byKey(const Key('panchang_today'))), findsNothing);
    expect(inPage(find.byKey(const Key('panchang_notes'))), findsNothing);
    // Today is a teal bar button, enabled away from today.
    final today = tester.widget<BarTextButton>(
      find.byKey(const Key('panchang_today')),
    );
    expect(today.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('panchang_today')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BarTextButton>(find.byKey(const Key('panchang_today')))
          .onPressed,
      isNull,
      reason: 'Today is disabled on today',
    );
  });

  testWidgets('calculation notes are an iOS sheet with Done', (tester) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 10, 8));
    await tester.tap(find.byKey(const Key('panchang_notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panchang_notes_sheet')), findsOneWidget);
    expect(find.byType(SheetBar), findsOneWidget);
    final body = find.text(
      'Everything is calculated on your phone for the chosen location, '
      'with its own time zone. Tithi, nakshatra, yoga and karana are taken '
      'at local sunrise; times after midnight are marked as the next day. '
      'Sunrise and sunset use the visible upper edge of the Sun at sea '
      'level, so hills and buildings can shift them by a few minutes.',
    );
    expect(styleOf(tester, body).fontSize, IosText.body);
    await tester.tap(find.byKey(const Key('panchang_notes_done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panchang_notes_sheet')), findsNothing);
  });

  testWidgets('location pill is a glass capsule; time zone at the far right', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(
      tester,
      premium: premium,
      date: DateTime(2026, 10, 8),
      city: const PanchangCity(
        id: 'custom',
        label: 'New York',
        latitude: 40.7128,
        longitude: -74.006,
        timeZoneId: 'America/New_York',
      ),
    );
    final pill = find.byKey(const Key('panchang_city_selector'));
    final name = find.descendant(of: pill, matching: find.text('New York'));
    expect(panelAround(tester, name).radius, greaterThanOrEqualTo(100));
    expect(
      find.descendant(of: pill, matching: find.byIcon(Icons.pin_drop)),
      findsOneWidget,
    );
    expect(styleOf(tester, name).fontSize, IosText.subheadline);
    expect(styleOf(tester, name).fontWeight, FontWeight.w600);
    // Arun's iPhone screenshot: city, pin and chevron all in teal.
    expect(styleOf(tester, name).color, IosColors.teal);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: pill,
              matching: find.byIcon(Icons.keyboard_arrow_down),
            ),
          )
          .color,
      IosColors.teal,
    );
    // Every city shows its time zone like IST, inside the capsule (never
    // the IANA name).
    final zone = find.descendant(
      of: pill,
      matching: find.byKey(const Key('panchang_city_zone')),
    );
    expect(tester.widget<Text>(zone).data, anyOf('EDT', 'EST'));
    expect(find.text('America/New_York'), findsNothing);
  });

  testWidgets('date stepper is glass radius 16 with a 17 semibold title', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 10, 8));
    final stepper = find.byKey(const Key('panchang_stepper'));
    expect(tester.widget<GlassPanel>(stepper).radius, 16);
    expect(
      find.descendant(
        of: stepper,
        matching: find.byIcon(Icons.calendar_month_outlined),
      ),
      findsOneWidget,
    );
    final title = find
        .descendant(of: stepper, matching: find.text('Thu, 8 Oct 2026'))
        .first;
    expect(styleOf(tester, title).fontSize, IosText.headline);
    expect(styleOf(tester, title).fontWeight, FontWeight.w600);
    // The screenshot: the date, its calendar icon and both chevrons teal.
    expect(styleOf(tester, title).color, IosColors.teal);
    for (final icon in [
      Icons.calendar_month_outlined,
      Icons.chevron_left,
      Icons.chevron_right,
    ]) {
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: stepper, matching: find.byIcon(icon)),
            )
            .color,
        IosColors.teal,
      );
    }
  });

  testWidgets('day picker is a sheet with a graphical calendar, Today, Done', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 10, 8));
    await tester.tap(find.byKey(const Key('panchang_tab_daily')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panchang_selected_date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byKey(const Key('panchang_day_picker_today')), findsOneWidget);
    // Picking a day changes the date at once, as the iOS binding does.
    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('20'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panchang_day_picker_done')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('panchang_stepper')),
        matching: find.text('Tue, 20 Oct 2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the location is the Home city picker as an iOS sheet: title '
      'and Cancel, popular cities, coordinates checked before saving', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 10, 8));
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final bar = find.byType(SheetBar);
    expect(bar, findsOneWidget);
    expect(tester.widget<SheetBar>(bar).title, 'Panchang location');
    expect(find.byKey(const Key('city_picker_cancel')), findsOneWidget);
    expect(find.byKey(const Key('ekadashi_location_search')), findsOneWidget);
    expect(find.text('Popular cities'), findsOneWidget);
    final list = find
        .descendant(
          of: find.byKey(const Key('city_picker_list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('location_save')),
      400,
      scrollable: list,
    );
    await tester.enterText(find.byKey(const Key('location_latitude')), '400');
    await tester.tap(find.byKey(const Key('location_save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from -90 to 90'), findsOneWidget);
    await tester.tap(find.byKey(const Key('city_picker_cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(SheetBar), findsNothing);
  });

  testWidgets('a location that cannot be saved shows a toast', (tester) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(
      tester,
      premium: premium,
      date: DateTime(2026, 10, 8),
      city: null,
      store: _FailingStore(),
    );
    await tester.tap(find.byKey(const Key('panchang_city_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ekadashi_city_geonames-1275339')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app_toast')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('Key days: glass chips in category colours, banner Unlock '
      'beside the text, glass rows', (tester) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 11, 8));
    await tester.tap(find.byKey(const Key('panchang_tab_keydays')));
    await tester.pumpAndSettle();
    final chip = find.byKey(const Key('panchang_key_filter_ekadashi'));
    expect(tester.widget(chip), isA<GlassChip>());
    expect(
      tester.widget<GlassChip>(chip).color,
      Color(SearchCategory.ekadashi.color),
    );
    final unlock = find.byKey(const Key('panchang_key_days_unlock'));
    expect(tester.widget(unlock), isA<FilledButton>());
    final text = find.text(
      'Festivals and observances are part of Premium. Ekadashis are free.',
    );
    expect(
      (tester.getCenter(unlock).dy - tester.getCenter(text).dy).abs(),
      lessThan(12),
      reason: 'the Unlock button is beside the text',
    );
    expect(
      tester.getRect(unlock).left,
      greaterThan(tester.getRect(text).right),
    );
    expect(panelAround(tester, unlock).radius, 18);
    expect(panelAround(tester, unlock).tint, IosColors.amber);
    final title = find.descendant(
      of: find.byKey(const Key('panchang_key_days')),
      matching: find.text('Deepavali (Lakshmi Puja)'),
    );
    expect(styleOf(tester, title).fontSize, IosText.headline);
    expect(panelAround(tester, title).radius, 18);
    // Locked rows: a lock in the tile and a lock on the right, the
    // category alone as the subtitle; unlocked rows end in a chevron.
    final locked = find.ancestor(
      of: title,
      matching: find.byType(PanchangPanel),
    );
    expect(
      find.descendant(of: locked, matching: find.byIcon(Icons.lock)),
      findsNWidgets(2),
    );
    final festival = find.descendant(
      of: locked,
      matching: find.textContaining('Festival'),
    );
    expect(festival, findsOneWidget);
    expect(
      tester.widget<Text>(festival).data ??
          tester.widget<Text>(festival).textSpan!.toPlainText(),
      isNot(contains('·')),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('panchang_key_days')),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsWidgets,
      reason: 'the free Ekadashi rows end in a chevron',
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<GlassChip>(chip).selected, isTrue);
  });

  testWidgets('Daily: hero radius 24, tithi 28 bold, status pills, glass '
      'sun and moon tiles, upgrade card radius 22', (tester) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 10, 8));
    await tester.tap(find.byKey(const Key('panchang_tab_daily')));
    await tester.pumpAndSettle();
    final hero = find.byKey(const Key('panchang_daily_overview'));
    expect(tester.widget<GlassPanel>(hero).radius, 24);
    expect(tester.widget<GlassPanel>(hero).tint, IosColors.teal);
    final tithi = find.byKey(const Key('panchang_tithi_title'));
    expect(styleOf(tester, tithi).fontSize, IosText.title);
    expect(styleOf(tester, tithi).fontWeight, FontWeight.w700);
    expect(
      find.descendant(of: hero, matching: find.byType(StatusPill)),
      findsAtLeastNWidgets(2),
    );
    final sunrise = find.text('Sunrise');
    expect(panelAround(tester, sunrise).radius, 18);
    expect(find.byIcon(Icons.wb_twilight), findsNWidgets(2));
    final unlock = find.byKey(const Key('panchang_unlock_button'));
    await tester.ensureVisible(unlock);
    await tester.pumpAndSettle();
    expect(panelAround(tester, unlock).radius, 22);
    final style = tester.widget<FilledButton>(unlock).style!;
    expect(style.shape?.resolve({}), isA<StadiumBorder>());
    expect(style.backgroundColor?.resolve({}), IosColors.teal);
  });

  testWidgets('Daily premium: card titles 17 semibold, rows 15, labels not '
      'squeezed, sparkles for observances, iOS colours', (tester) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    // Deepavali 2026 (a major observance) in New Delhi.
    await show(tester, premium: premium, date: DateTime(2026, 11, 8));
    await tester.tap(find.byKey(const Key('panchang_tab_daily')));
    await tester.pumpAndSettle();
    final limbs = find.byKey(const Key('panchang_limbs'));
    expect(
      panelAround(
        tester,
        find.descendant(of: limbs, matching: find.text('Five limbs')),
      ).radius,
      20,
    );
    final cardTitle = find.descendant(
      of: limbs,
      matching: find.text('Five limbs'),
    );
    expect(styleOf(tester, cardTitle).fontSize, IosText.headline);
    expect(styleOf(tester, cardTitle).fontWeight, FontWeight.w600);
    final label = find.descendant(of: limbs, matching: find.text('Nakshatra'));
    expect(styleOf(tester, label).fontSize, IosText.subheadline);
    expect(
      find.descendant(of: limbs, matching: find.byIcon(Icons.hexagon_outlined)),
      findsNothing,
    );
    final observances = find.byKey(const Key('panchang_observances'));
    await tester.ensureVisible(observances);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: observances, matching: find.byIcon(Icons.star)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: observances,
        matching: find.byKey(const Key('panchang_sparkle')),
      ),
      findsWidgets,
    );
    expect(PanchangColors.amber, IosColors.amber);
    expect(PanchangColors.avoid, IosColors.missed);
  });

  testWidgets('a short value leaves the label room (not a third)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: PanchangValueRow(label: 'Twenty one characters', value: '5'),
          ),
        ),
      ),
    );
    final label = find.text('Twenty one characters');
    expect(styleOf(tester, label).fontSize, IosText.subheadline);
    expect(tester.getSize(label).height, lessThan(24), reason: 'one line');
    final value = find.text('5');
    expect(styleOf(tester, value).fontSize, IosText.subheadline);
    expect(styleOf(tester, value).fontWeight, FontWeight.w600);
  });

  testWidgets('Muhurta: iOS segmented control, dot-grid Choghadiya icon', (
    tester,
  ) async {
    final premium = await premiumService(true);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 10, 8));
    await tester.tap(find.byKey(const Key('panchang_tab_muhurta')));
    await tester.pumpAndSettle();
    final control = find.byKey(const Key('panchang_day_night'));
    expect(
      tester.widget(control),
      isA<CupertinoSlidingSegmentedControl<bool>>(),
    );
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.byKey(const Key('panchang_dot_grid')), findsOneWidget);
    expect(find.byIcon(Icons.grid_view), findsNothing);
    await tester.tap(find.text('Night'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoSlidingSegmentedControl<bool>>(control).groupValue,
      isTrue,
    );
  });

  testWidgets('Ekadashi: glass tradition chips, rule 15, cards radius 18', (
    tester,
  ) async {
    final premium = await premiumService(false);
    addTearDown(premium.dispose);
    await show(tester, premium: premium, date: DateTime(2026, 11, 8));
    await tester.ensureVisible(find.byKey(const Key('panchang_tab_ekadashi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panchang_tab_ekadashi')));
    await tester.pumpAndSettle();
    final chip = find.byKey(const Key('panchang_tradition_gaudiya'));
    expect(tester.widget(chip), isA<GlassChip>());
    expect(find.byType(ChoiceChip), findsNothing);
    final cards = find.byKey(const Key('panchang_fast_card'));
    expect(cards, findsWidgets);
    expect(tester.widget<GlassPanel>(cards.first).radius, 18);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<GlassChip>(chip).selected, isTrue);
    final rule = find.byKey(const Key('panchang_tradition_rule'));
    expect(styleOf(tester, rule).fontSize, IosText.subheadline);
  });
}

class _FailingStore extends PanchangLocationStore {
  @override
  Future<PanchangCity?> load() async => null;

  @override
  Future<void> save(PanchangCity city) async => throw StateError('disk full');
}
