import 'package:ekadashi_calendar/widgets/app_icons.dart';
import 'dart:async';

import 'package:ekadashi_calendar/screens/premium_screen.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/premium_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/widgets/app_background.dart';
import 'package:ekadashi_calendar/widgets/ios_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/premium_fixture.dart';

/// Google Play answers only when the test says so (the paywall is busy).
class _SlowFixture extends PremiumFixture {
  Completer<void>? gate;
  @override
  Future<Map<String, DateTime?>> ownedProducts() async {
    await gate?.future;
    return super.ownedProducts();
  }
}

/// The paywall follows the iOS PremiumView: a sheet with a centred inline
/// title and an X, the app background, the reason, iOS-sized features,
/// glass status and plan cards, a teal spinner, a capsule buy button,
/// leading teal links and toasts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LanguageService lang;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    lang = LanguageService();
  });

  Future<(PremiumService, FixtureBilling)> pump(
    WidgetTester tester, {
    PremiumFixture? source,
    Set<String> owned = const {},
    String? reason,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final premium = PremiumService(
      entitlements: source ?? (PremiumFixture()..premium = false),
    );
    if (owned.isNotEmpty) premium.applyOwned(owned);
    addTearDown(premium.dispose);
    final billing = FixtureBilling(premium);
    addTearDown(billing.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: lang),
          ChangeNotifierProvider.value(value: premium),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          home: PremiumScreen(billingOverride: billing, reasonKey: reason),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (premium, billing);
  }

  testWidgets(
    'confirmed ownership advances the selected upgrade and retains lifetime',
    (tester) async {
      final (premium, billing) = await pump(tester);
      await tester.tap(find.byKey(const Key('premium_plan_monthly')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('premium_plan_monthly')))
            .properties
            .selected,
        isTrue,
      );
      billing.currentPlanId = 'monthly';
      premium.applyOwned({PremiumService.subscriptionId});
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('premium_plan_yearly')))
            .properties
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('premium_plan_yearly')));
      billing.currentPlanId = 'yearly';
      premium.applyOwned({PremiumService.subscriptionId});
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('premium_plan_lifetime')))
            .properties
            .selected,
        isTrue,
      );
      premium.applyOwned({PremiumService.lifetimeId});
      await tester.pumpAndSettle();
      final lifetime = find.byKey(const Key('premium_plan_lifetime'));
      expect(lifetime, findsOneWidget);
      expect(tester.widget<Semantics>(lifetime).properties.selected, isTrue);
      final opacity = tester.widget<Opacity>(
        find.descendant(of: lifetime, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 1);
      expect(
        billing.canBuy(billing.plans.last),
        isFalse,
        reason: 'Owning Lifetime must never allow a duplicate charge',
      );
    },
  );

  testWidgets('Premium X has the iOS 44 point glass enclosure', (tester) async {
    await pump(tester);
    final close = find.byKey(const Key('premium_close'));
    expect(
      find.ancestor(of: close, matching: find.byType(GlassPanel)),
      findsOneWidget,
    );
    expect(tester.getSize(close), const Size(44, 44));
    expect(
      tester.getCenter(close).dx,
      lessThan(tester.getCenter(find.text('Ekadashi Premium')).dx),
    );
  });

  testWidgets('bar, background, reason and features as on iOS', (tester) async {
    await pump(tester, reason: 'search_premium_locked');
    // A centred inline title and an X to close.
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.centerTitle, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('premium_close')),
        matching: find.byIcon(AppIcons.close),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PremiumScreen),
        matching: find.byType(AppBackground),
      ),
      findsOneWidget,
    );
    // Why it opened: a teal info icon and a 17 pt semibold line.
    final reason = find.byKey(const Key('premium_reason'));
    final info = tester.widget<Icon>(
      find.descendant(of: reason, matching: find.byIcon(AppIcons.info)),
    );
    expect(info.color, IosColors.teal);
    final reasonText = tester.widget<Text>(
      find.text(lang.translate('search_premium_locked')),
    );
    expect(reasonText.style?.fontSize, IosText.body);
    expect(reasonText.style?.fontWeight, FontWeight.w600);
    // The three features at 17 pt with the iOS symbols; the Panchang one
    // uses the iOS wording.
    for (final (key, icon) in [
      ('premium_feature_calendar', AppIcons.premiumCalendar),
      ('premium_feature_vrat', AppIcons.premiumVrat),
      ('premium_feature_panchang_v2', AppIcons.premiumPanchang),
    ]) {
      final text = tester.widget<Text>(find.text(lang.translate(key)));
      expect(text.style?.fontSize, IosText.body, reason: key);
      expect(find.byIcon(icon), findsOneWidget, reason: key);
    }
    expect(find.text(lang.translate('premium_feature_panchang')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass plan cards, capsule buy button and centred links', (
    tester,
  ) async {
    await pump(tester);
    for (final id in ['monthly', 'yearly', 'lifetime']) {
      final plan = find.byKey(Key('premium_plan_$id'));
      expect(
        find.descendant(of: plan, matching: find.byType(GlassPanel)),
        findsOneWidget,
        reason: id,
      );
      final name = tester.widget<Text>(
        find.descendant(
          of: plan,
          matching: find.text(lang.translate('premium_$id')),
        ),
      );
      expect(name.style?.fontSize, IosText.subheadline);
      expect(name.style?.fontWeight, FontWeight.w600);
    }
    final price = tester.widget<Text>(find.text('₹499').first);
    expect(price.style?.fontSize, IosText.title3);
    final buy = tester.widget<FilledButton>(
      find.byKey(const Key('premium_buy')),
    );
    expect(buy.style?.shape?.resolve({}), isA<StadiumBorder>());
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('premium_buy')),
        matching: find.byType(Text),
      ),
    );
    expect(label.style?.fontSize, IosText.headline);
    expect(label.style?.fontWeight, FontWeight.w600);
    // Links: two centred rows of 13 pt teal, as on iOS (25 Nov 2026).
    final rows = find.descendant(
      of: find.byKey(const Key('premium_links')),
      matching: find.byType(Wrap),
    );
    expect(rows, findsNWidgets(2));
    for (final row in tester.widgetList<Wrap>(rows)) {
      expect(row.alignment, WrapAlignment.center);
      expect(row.spacing, greaterThanOrEqualTo(12));
    }
    final restore = tester.widget<Text>(
      find.text(lang.translate('premium_restore')),
    );
    expect(restore.style?.fontSize, IosText.footnote);
    expect(restore.style?.color, IosColors.teal);
    expect(
      tester.getTopLeft(find.text(lang.translate('premium_restore'))).dx,
      greaterThan(40),
      reason: 'centred, not at the leading edge',
    );
    expect(tester.takeException(), isNull);
  });

  // Arun (26 Nov 2026): "Cancel subscription in Google Play" was not clear on
  // the orange card; it looks like the Settings card's Manage button.
  for (final dark in [true, false]) {
    testWidgets('Cancel subscription is a clear outlined button '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await pump(
        tester,
        owned: {PremiumService.subscriptionId, PremiumService.lifetimeId},
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      );
      final style = tester
          .widget<OutlinedButton>(
            find.byKey(const Key('premium_cancel_subscription')),
          )
          .style!;
      final expected = dark ? Colors.white : Colors.black;
      final label = style.foregroundColor!.resolve({})!;
      final outline = style.side!.resolve({})!.color;
      expect(label.toARGB32() & 0xFFFFFF, expected.toARGB32() & 0xFFFFFF);
      expect(outline.toARGB32() & 0xFFFFFF, expected.toARGB32() & 0xFFFFFF);
      expect(outline.a, greaterThanOrEqualTo(.8));
    });
  }

  testWidgets('member status cards are glass panels', (tester) async {
    await pump(tester, owned: {PremiumService.subscriptionId});
    expect(
      find.descendant(
        of: find.byKey(const Key('premium_active')),
        matching: find.byType(GlassPanel),
      ),
      findsOneWidget,
    );
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy shows a teal spinner; restore answers with a toast', (
    tester,
  ) async {
    final source = _SlowFixture()..premium = false;
    final (premium, _) = await pump(tester, source: source);
    source.gate = Completer<void>();
    unawaited(premium.refresh());
    await tester.pump();
    expect(premium.busy, isTrue);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, IosColors.teal);
    source.gate!.complete();
    await tester.pumpAndSettle();

    await tester.tap(find.text(lang.translate('premium_restore')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('app_toast')),
        matching: find.text(lang.translate('premium_restore_none')),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lifetime confirmation buttons are teal', (tester) async {
    await pump(tester, owned: {PremiumService.subscriptionId});
    await tester.tap(find.byKey(const Key('premium_plan_lifetime')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('premium_buy')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    for (final key in ['cancel', 'premium_buy_lifetime_anyway']) {
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text(lang.translate(key)),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.style?.foregroundColor?.resolve({}), IosColors.teal);
    }
    expect(tester.takeException(), isNull);
  });
}
