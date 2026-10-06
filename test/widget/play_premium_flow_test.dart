import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/l10n/generated/app_localizations.dart';
import 'package:ekadashi_calendar/models/vrat_tracker_models.dart';
import 'package:ekadashi_calendar/screens/calendar_screen.dart';
import 'package:ekadashi_calendar/screens/panchang_screen.dart';
import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/screens/vrat_tracker/record_vrat_dialog.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/google_calendar_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/play_billing_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/vrat_tracker_service.dart';
import '../support/memory_calendar_repository.dart';
import '../support/premium_fixture.dart';
import '../support/fake_free_sync_registry.dart';
import '../unit/google_reconciliation_test.dart' show event;
import 'multi_year_calendar_test.dart' show UiGoogle;

class SignInFailingGoogle extends UiGoogle {
  SignInFailingGoogle() {
    account = null;
  }
  @override
  Future<bool> signIn() async =>
      throw PlatformException(code: 'sign_in_failed', message: '10');
}

final today = DateTime(2026, 10, 5);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = EkadashiService();
  late LanguageService lang;
  setUpAll(() async {
    await data.initializeData();
    await initializeDateFormatting();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    lang = LanguageService();
    await lang.changeLanguage('en');
  });

  PremiumService freeUser(PremiumFixture source) {
    final premium = PremiumService(entitlements: source..premium = false);
    addTearDown(premium.dispose);
    return premium;
  }

  Future<FixtureBilling> pumpPaywall(
    WidgetTester tester,
    PremiumService premium, {
    String? currentPlan,
  }) async {
    final billing = FixtureBilling(premium);
    addTearDown(billing.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: lang),
          ChangeNotifierProvider.value(value: premium),
        ],
        child: MaterialApp(home: PremiumScreen(billingOverride: billing)),
      ),
    );
    await tester.pumpAndSettle();
    billing.currentPlanId = currentPlan;
    billing.notifyListeners();
    await tester.pumpAndSettle();
    return billing;
  }

  String ctaLabel(WidgetTester tester) {
    final cta = find.byKey(const Key('premium_buy'));
    return tester
        .widgetList<Text>(find.descendant(of: cta, matching: find.byType(Text)))
        .map((t) => t.data)
        .join();
  }

  testWidgets('Paywall: plans side by side, one buy button, no sign-in', (
    tester,
  ) async {
    final premium = freeUser(PremiumFixture());
    await pumpPaywall(tester, premium);
    expect(find.text('Sign in securely with Google'), findsNothing);
    expect(find.text('Fasting rewards'), findsNothing);
    expect(find.text(lang.translate('premium_continue_free')), findsNothing);
    for (final feature in [
      'premium_feature_calendar',
      'premium_feature_vrat',
      'premium_feature_panchang',
    ]) {
      expect(find.text(lang.translate(feature)), findsOneWidget);
    }
    final tops = [
      for (final id in ['monthly', 'yearly', 'lifetime'])
        tester.getTopLeft(find.byKey(Key('premium_plan_$id'))),
    ];
    expect(tops.map((o) => o.dy).toSet(), hasLength(1), reason: 'one row');
    expect(tops[0].dx < tops[1].dx && tops[1].dx < tops[2].dx, isTrue);
    expect(find.text(lang.translate('premium_best_value')), findsOneWidget);
    // Yearly is preselected; one call to action buys the selected plan.
    expect(find.byKey(const Key('premium_buy')), findsOneWidget);
    expect(ctaLabel(tester), contains('₹499'));
    await tester.tap(find.byKey(const Key('premium_plan_monthly')));
    await tester.pumpAndSettle();
    expect(ctaLabel(tester), contains('₹99'));
    final cta = tester.widget<FilledButton>(
      find.byKey(const Key('premium_buy')),
    );
    expect(cta.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Paywall: a monthly subscriber can only pick another plan', (
    tester,
  ) async {
    final premium = PremiumService(entitlements: PremiumFixture())
      ..applyOwned({PremiumService.subscriptionId});
    addTearDown(premium.dispose);
    await pumpPaywall(tester, premium, currentPlan: 'monthly');
    expect(find.byKey(const Key('premium_active')), findsOneWidget);
    expect(find.byKey(const Key('premium_current_monthly')), findsOneWidget);
    await tester.tap(find.byKey(const Key('premium_plan_monthly')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('premium_buy')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('premium_plan_lifetime')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('premium_buy')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Paywall plans fit a 320dp phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final code in ['en', 'ta', 'hi', 'te']) {
      await lang.changeLanguage(code);
      await pumpPaywall(tester, freeUser(PremiumFixture()));
      expect(tester.takeException(), isNull, reason: code);
    }
  });

  Future<UiGoogle> pumpCalendar(
    WidgetTester tester,
    PremiumService premium, {
    UiGoogle? google,
    DateTime? now,
    MemoryCalendarRepository? repository,
    FakeFreeSyncRegistry? registry,
  }) async {
    final repo = repository ?? MemoryCalendarRepository();
    final auth = google ?? UiGoogle();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: premium),
          ChangeNotifierProvider<PlayBillingService>(
            create: (_) => FixtureBilling(premium),
          ),
          ChangeNotifierProvider.value(value: lang),
          ChangeNotifierProvider(create: (_) => VratTrackerService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CalendarScreen(
            ekadashiList: data.getEkadashis(
              timezone: 'IST',
              languageCode: 'en',
            ),
            repository: repo,
            clock: () => now ?? today,
            freeSyncRegistry: registry ?? FakeFreeSyncRegistry(),
            googleService: GoogleCalendarService(auth: auth, repository: repo),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  // The sync spinner animates while the picker is open, so avoid settling.
  Future<void> tapImport(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('import_google_year')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> importSelected(WidgetTester tester) async {
    await tester.tap(find.text('Import selected'));
    await tester.pumpAndSettle();
  }

  Future<bool?> freeSyncUsed() async => (await SharedPreferences.getInstance())
      .getBool(CalendarScreen.freeSyncUsedKey);

  testWidgets('Free Calendar gets one free sync, of the month on screen', (
    tester,
  ) async {
    final premium = freeUser(PremiumFixture());
    final registry = FakeFreeSyncRegistry();
    final google = await pumpCalendar(tester, premium, registry: registry);
    await tapImport(tester);
    expect(find.byType(PremiumScreen), findsNothing);
    await importSelected(tester);
    expect(google.min, DateTime(2026, 10, 1));
    expect(google.max, DateTime(2026, 11, 1));
    expect(find.text(lang.translate('google_free_sync_used')), findsOneWidget);
    expect(await freeSyncUsed(), isTrue);
    // Also recorded for the Google account (free database), so a reinstall
    // or another phone cannot reuse it.
    expect(registry.recorded, DateTime(2026, 10));
    expect(registry.tokens, everyElement('google-id-token-account-a'));
    // The free sync is used: the next sync, even of the same month, is paid.
    google.min = null;
    await tester.tap(find.byKey(const Key('import_google_year')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(google.min, isNull);
  });

  testWidgets('After a reinstall the Google account still has no free sync', (
    tester,
  ) async {
    // Fresh install: no local flag, but this Google account used it before.
    final premium = freeUser(PremiumFixture());
    final google = UiGoogle();
    final registry = FakeFreeSyncRegistry()..recorded = DateTime(2026, 9);
    await pumpCalendar(tester, premium, google: google, registry: registry);
    await tapImport(tester);
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(find.text('Import selected'), findsNothing);
    expect(google.min, isNull);
    expect(await freeSyncUsed(), isTrue);
  });

  testWidgets('The free sync imports whichever month is being viewed', (
    tester,
  ) async {
    final premium = freeUser(PremiumFixture());
    final google = await pumpCalendar(tester, premium);
    tester
        .state<CalendarScreenState>(find.byType(CalendarScreen))
        .selectDate(DateTime(2027, 3, 15));
    await tester.pumpAndSettle();
    await tapImport(tester);
    await importSelected(tester);
    expect(google.min, DateTime(2027, 3, 1));
    expect(google.max, DateTime(2027, 4, 1));
  });

  testWidgets('Closing the picker or the Calendar and retrying keeps the '
      'free sync', (tester) async {
    final premium = freeUser(PremiumFixture());
    final google = UiGoogle();
    final registry = FakeFreeSyncRegistry();
    await pumpCalendar(tester, premium, google: google, registry: registry);
    await tapImport(tester);
    Navigator.of(tester.element(find.text('Import selected'))).pop();
    await tester.pumpAndSettle();
    expect(google.min, isNull);
    // Leave the Calendar entirely and come back.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpCalendar(tester, premium, google: google, registry: registry);
    expect(await freeSyncUsed(), isNot(isTrue));
    expect(registry.recorded, isNull);
    await tapImport(tester);
    expect(find.byType(PremiumScreen), findsNothing);
    await importSelected(tester);
    expect(google.min, DateTime(2026, 10, 1));
  });

  testWidgets('A failed free import keeps the free sync', (tester) async {
    final premium = freeUser(PremiumFixture());
    final google = UiGoogle()..fail = true;
    final registry = FakeFreeSyncRegistry();
    await pumpCalendar(tester, premium, google: google, registry: registry);
    await tapImport(tester);
    await importSelected(tester);
    expect(find.text(lang.translate('google_sync_failed')), findsOneWidget);
    expect(await freeSyncUsed(), isNot(isTrue));
    expect(registry.recorded, isNull);
  });

  testWidgets('If the free-sync record cannot be checked, nothing is handed '
      'out, Premium is offered and the free sync stays available', (
    tester,
  ) async {
    final premium = freeUser(PremiumFixture());
    final registry = FakeFreeSyncRegistry()..fail = true;
    final google = await pumpCalendar(tester, premium, registry: registry);
    await tester.tap(find.byKey(const Key('import_google_year')));
    await tester.pumpAndSettle();
    expect(find.text('Import selected'), findsNothing);
    expect(find.byType(PremiumScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('premium_close')));
    await tester.pumpAndSettle();
    expect(google.min, isNull);
    expect(await freeSyncUsed(), isNot(isTrue));
  });

  testWidgets('Lifetime syncs every calendar year the app has', (tester) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()
        ..premium = false
        ..lifetime = true
        ..purchasedAt = DateTime(2026, 11, 20),
    );
    addTearDown(premium.dispose);
    await premium.refresh();
    final google = await pumpCalendar(tester, premium);
    await tapImport(tester);
    await importSelected(tester);
    expect(google.min, DateTime(2026, 1, 1));
    expect(google.max, DateTime(2028, 1, 1));
  });

  testWidgets('When a monthly plan lapses, the events Premium synced are '
      'removed and the free month stays', (tester) async {
    SharedPreferences.setMockInitialValues({
      CalendarScreen.freeSyncUsedKey: true,
      CalendarScreen.freeSyncMonthKey: '2026-10',
    });
    final source = PremiumFixture()..purchasedAt = DateTime(2026, 9, 10);
    final premium = PremiumService(entitlements: source);
    addTearDown(premium.dispose);
    await premium.refresh();
    final repo = MemoryCalendarRepository();
    final google = UiGoogle()
      ..events = [
        event('Free month event', start: '2026-10-10', end: '2026-10-11'),
        event('Premium event', start: '2027-01-10', end: '2027-01-11'),
      ];
    await pumpCalendar(tester, premium, google: google, repository: repo);
    await tapImport(tester);
    await importSelected(tester);
    expect(
      repo.entries.values.map((e) => e.title),
      containsAll(['Free month event', 'Premium event']),
    );
    // The monthly plan was cancelled and has now expired in Google Play.
    source.premium = false;
    await premium.refresh();
    await tester.pumpAndSettle();
    expect(repo.entries.values.map((e) => e.title), ['Free month event']);
    expect(
      find.text(lang.translate('google_premium_events_removed')),
      findsOneWidget,
    );
  });

  testWidgets('Premium-synced events are removed on the next launch after a '
      'lapse, but kept while Google Play is unreachable', (tester) async {
    SharedPreferences.setMockInitialValues({
      CalendarScreen.freeSyncUsedKey: true,
    });
    final source = PremiumFixture()..purchasedAt = DateTime(2026, 9, 10);
    final premium = PremiumService(entitlements: source);
    addTearDown(premium.dispose);
    await premium.refresh();
    final repo = MemoryCalendarRepository();
    final google = UiGoogle()
      ..events = [
        event('Premium event', start: '2027-01-10', end: '2027-01-11'),
      ];
    await pumpCalendar(tester, premium, google: google, repository: repo);
    await tapImport(tester);
    await importSelected(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    // Offline or Play unavailable: never treat that as a cancellation.
    source.fail = true;
    await premium.refresh();
    await pumpCalendar(tester, premium, google: google, repository: repo);
    expect(repo.entries.values.map((e) => e.title), ['Premium event']);
    await tester.pumpWidget(const SizedBox.shrink());
    // Later launch: Play answers and the subscription has ended.
    source
      ..fail = false
      ..premium = false;
    await premium.refresh();
    await pumpCalendar(tester, premium, google: google, repository: repo);
    expect(repo.entries, isEmpty);
  });

  testWidgets('After the free sync, buying premium continues into the '
      'subscription-year import', (tester) async {
    SharedPreferences.setMockInitialValues({
      CalendarScreen.freeSyncUsedKey: true,
    });
    final source = PremiumFixture();
    final premium = freeUser(source);
    final google = await pumpCalendar(tester, premium);
    await tester.tap(find.byKey(const Key('import_google_year')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(google.min, isNull);
    // Play purchase made today.
    premium.applyOwned(
      {PremiumService.subscriptionId},
      purchasedAt: {PremiumService.subscriptionId: today},
    );
    await tester.tap(find.byKey(const Key('premium_close')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await importSelected(tester);
    expect(google.min, DateTime(2026, 10, 1));
    expect(google.max, DateTime(2027, 10, 1));
  });

  testWidgets('An annual plan bought in November syncs until next October', (
    tester,
  ) async {
    final premium = PremiumService(
      entitlements: PremiumFixture()..purchasedAt = DateTime(2026, 11, 20),
    );
    addTearDown(premium.dispose);
    await premium.refresh();
    final google = await pumpCalendar(
      tester,
      premium,
      now: DateTime(2026, 11, 21),
    );
    await tapImport(tester);
    await importSelected(tester);
    expect(google.min, DateTime(2026, 11, 1));
    expect(google.max, DateTime(2027, 11, 1));
    expect(
      find.text(
        lang.translateWithArgs('imported_google_range', [
          '0',
          'Nov 2026',
          'Oct 2027',
        ]),
      ),
      findsOneWidget,
    );
  });

  testWidgets('A cancelled or expired subscription stops syncing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      CalendarScreen.freeSyncUsedKey: true,
    });
    final source = PremiumFixture()..purchasedAt = DateTime(2026, 9, 10);
    final premium = PremiumService(entitlements: source);
    addTearDown(premium.dispose);
    await premium.refresh();
    final google = await pumpCalendar(tester, premium);
    await tapImport(tester);
    await importSelected(tester);
    expect(google.min, DateTime(2026, 9, 1));
    expect(google.max, DateTime(2027, 9, 1));
    // The monthly plan was cancelled and its paid month ended: Google Play
    // no longer reports it as owned.
    source.premium = false;
    await premium.refresh();
    google.min = null;
    await tester.tap(find.byKey(const Key('import_google_year')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(google.min, isNull);
  });

  testWidgets('Calendar reports a Google sign-in failure, not a cancel', (
    tester,
  ) async {
    final premium = freeUser(PremiumFixture());
    await pumpCalendar(tester, premium, google: SignInFailingGoogle());
    await tester.tap(find.byKey(const Key('import_google_year')));
    await tester.pumpAndSettle();
    expect(find.text(lang.translate('google_sign_in_failed')), findsOneWidget);
    expect(find.text(lang.translate('sign_in_cancelled')), findsNothing);
  });

  testWidgets('Disconnecting Google keeps a Play premium purchase', (
    tester,
  ) async {
    final premium = PremiumService(entitlements: PremiumFixture());
    addTearDown(premium.dispose);
    await premium.refresh();
    await pumpCalendar(tester, premium);
    final disconnect = find.byKey(const Key('disconnect_google'));
    await tester.ensureVisible(disconnect);
    await tester.tap(disconnect);
    await tester.pumpAndSettle();
    expect(premium.isPremium, isTrue);
  });

  Future<(VratTrackerService, List<EkadashiDate>)> pumpVrat(
    WidgetTester tester,
    PremiumService premium, {
    int existing = 3,
  }) async {
    final occurrences = data
        .getEkadashis(timezone: 'IST', languageCode: 'en')
        .where((e) => e.date.isBefore(DateTime.now()))
        .toList();
    final tracker = VratTrackerService();
    await tracker.init(occurrences: occurrences);
    addTearDown(tracker.dispose);
    for (final e in occurrences.take(existing)) {
      await tracker.recordVrat(
        ekadashiOccurrenceId: e.id,
        occurrenceUid: e.occurrenceUid,
        ekadashiDate: e.date.toIso8601String().substring(0, 10),
        ekadashiName: e.name,
        status: ObservanceStatus.observed,
      );
    }
    final billing = FixtureBilling(premium);
    addTearDown(billing.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: lang),
          ChangeNotifierProvider.value(value: premium),
          ChangeNotifierProvider<PlayBillingService>.value(value: billing),
          ChangeNotifierProvider.value(value: tracker),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  for (final (i, e) in occurrences.take(existing + 1).indexed)
                    TextButton(
                      key: Key('open_vrat_$i'),
                      onPressed: () => RecordVratDialog.show(
                        context,
                        ekadashi: e,
                        allOccurrences: occurrences,
                        currentTimezone: 'IST',
                      ),
                      child: Text('open $i'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (tracker, occurrences);
  }

  Future<void> save(WidgetTester tester, String label) async {
    final button = find.widgetWithText(ElevatedButton, lang.translate(label));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Vrat: the first three entries are free, the fourth opens the '
      'paywall and is not saved', (tester) async {
    final premium = freeUser(PremiumFixture());
    final (tracker, occurrences) = await pumpVrat(tester, premium);
    expect(VratTrackerService.freeEntryLimit, 3);
    await tester.tap(find.byKey(const Key('open_vrat_3')));
    await tester.pumpAndSettle();
    await save(tester, 'record_observance');
    expect(find.byType(PremiumScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('premium_close')));
    await tester.pumpAndSettle();
    expect(tracker.getRecordByUid(occurrences[3].occurrenceUid), isNull);
    expect(tracker.getAllRecords(), hasLength(3));
  });

  testWidgets('Vrat: editing an existing entry stays free', (tester) async {
    final premium = freeUser(PremiumFixture());
    final (tracker, occurrences) = await pumpVrat(tester, premium);
    await tester.tap(find.byKey(const Key('open_vrat_0')));
    await tester.pumpAndSettle();
    await save(tester, 'edit_record');
    expect(find.byType(PremiumScreen), findsNothing);
    expect(tracker.getAllRecords(), hasLength(3));
  });

  testWidgets('Vrat: buying premium from the limit saves the fourth entry', (
    tester,
  ) async {
    final premium = freeUser(PremiumFixture());
    final (tracker, occurrences) = await pumpVrat(tester, premium);
    await tester.tap(find.byKey(const Key('open_vrat_3')));
    await tester.pumpAndSettle();
    await save(tester, 'record_observance');
    expect(find.byType(PremiumScreen), findsOneWidget);
    premium.applyOwned({PremiumService.lifetimeId});
    await tester.tap(find.byKey(const Key('premium_close')));
    await tester.pumpAndSettle();
    expect(tracker.getRecordByUid(occurrences[3].occurrenceUid), isNotNull);
  });

  testWidgets('Panchang unlock returns to the full Panchang after purchase', (
    tester,
  ) async {
    // Pixel 2 portrait, as on the CI emulator.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final premium = freeUser(PremiumFixture());
    final billing = FixtureBilling(premium);
    addTearDown(billing.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: lang),
          ChangeNotifierProvider.value(value: premium),
          ChangeNotifierProvider<PlayBillingService>.value(value: billing),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PanchangScreen(initialDate: DateTime(2026, 10, 4)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final unlock = find.byKey(const Key('panchang_unlock_button'));
    expect(unlock, findsNothing, reason: 'Below the fold on a phone');
    await tester.scrollUntilVisible(
      unlock,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('panchang_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panchang_unlock_button')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    premium.applyOwned({PremiumService.subscriptionId});
    await tester.tap(find.byKey(const Key('premium_close')));
    await tester.pumpAndSettle();
    expect(find.text('Unlock full Panchang'), findsNothing);
    expect(find.text('Nakshatra'), findsWidgets);
  });
}
