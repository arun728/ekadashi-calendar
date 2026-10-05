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

  testWidgets('Paywall has no Google sign-in or rewards and can buy', (
    tester,
  ) async {
    final premium = freeUser(PremiumFixture());
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
    expect(find.byKey(const Key('premium_sign_in')), findsNothing);
    expect(find.text('Sign in securely with Google'), findsNothing);
    expect(find.text('Fasting rewards'), findsNothing);
    expect(find.text('Activate rewards'), findsNothing);
    expect(find.text('Delete cloud account'), findsNothing);
    final monthly = find.widgetWithText(FilledButton, 'Monthly · ₹99');
    expect(monthly, findsOneWidget);
    expect(tester.widget<FilledButton>(monthly).onPressed, isNotNull);
    for (final feature in [
      'premium_feature_calendar',
      'premium_feature_vrat',
      'premium_feature_panchang',
    ]) {
      expect(find.text(lang.translate(feature)), findsOneWidget);
    }
    for (final label in ['Yearly · ₹499', 'Lifetime · ₹999']) {
      final button = find.widgetWithText(FilledButton, label);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    }
  });

  Future<UiGoogle> pumpCalendar(
    WidgetTester tester,
    PremiumService premium, {
    UiGoogle? google,
  }) async {
    final repo = MemoryCalendarRepository();
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
            clock: () => today,
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

  testWidgets('Free Calendar imports the current month without a paywall', (
    tester,
  ) async {
    final premium = freeUser(PremiumFixture());
    final google = await pumpCalendar(tester, premium);
    await tapImport(tester);
    expect(find.byType(PremiumScreen), findsNothing);
    await tester.tap(find.text('Import selected'));
    await tester.pumpAndSettle();
    expect(google.min, DateTime(2026, 10, 1));
    expect(google.max, DateTime(2026, 11, 1));
    expect(
      find.text(lang.translate('google_month_imported_free')),
      findsOneWidget,
    );
  });

  testWidgets('Free Calendar for another year opens the paywall, then '
      'imports the whole year after purchase', (tester) async {
    final source = PremiumFixture();
    final premium = freeUser(source);
    final google = await pumpCalendar(tester, premium);
    await tester.tap(find.byKey(const Key('calendar_year_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import_google_year')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(google.min, isNull);
    premium.applyOwned({PremiumService.subscriptionId}); // Play purchase.
    await tester.tap(find.byKey(const Key('premium_close')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Import selected'));
    await tester.pumpAndSettle();
    expect(google.min, DateTime(2027, 1, 1));
    expect(google.max, DateTime(2028, 1, 1));
  });

  testWidgets('Premium Calendar imports the whole selected year', (
    tester,
  ) async {
    final premium = PremiumService(entitlements: PremiumFixture());
    addTearDown(premium.dispose);
    await premium.refresh();
    final google = await pumpCalendar(tester, premium);
    await tapImport(tester);
    await tester.tap(find.text('Import selected'));
    await tester.pumpAndSettle();
    expect(google.min, DateTime(2026, 1, 1));
    expect(google.max, DateTime(2027, 1, 1));
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
    await tester.ensureVisible(find.byKey(const Key('panchang_unlock_button')));
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
