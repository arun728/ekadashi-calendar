import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:ekadashi_calendar/screens/widget_preview_screen.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  final sampleEkadashis = [
    EkadashiDate(
      id: 1,
      name: 'Aja Ekadashi',
      date: DateTime.now(),
      fastBreakTime: '06:24 AM – 08:42 AM',
      fastStartTime: '05:48 AM',
      description: 'Aja Ekadashi description',
    ),
    EkadashiDate(
      id: 2,
      name: 'Indira Ekadashi',
      date: DateTime.now().add(const Duration(days: 2, hours: 8)),
      fastBreakTime: '06:15 AM – 08:30 AM',
      fastStartTime: '05:30 AM',
      description: 'Indira Ekadashi description',
    ),
    EkadashiDate(
      id: 3,
      name: 'Papankusha Ekadashi',
      date: DateTime(2026, 10, 11),
      fastBreakTime: '06:12 AM – 08:25 AM',
      fastStartTime: '05:32 AM',
      description: 'Papankusha Ekadashi description',
    ),
    EkadashiDate(
      id: 4,
      name: 'Rama Ekadashi',
      date: DateTime(2026, 10, 26),
      fastBreakTime: '06:18 AM – 08:35 AM',
      fastStartTime: '05:35 AM',
      description: 'Rama Ekadashi description',
    ),
    EkadashiDate(
      id: 5,
      name: 'Devaprabodhini Ekadashi',
      date: DateTime(2026, 11, 10),
      fastBreakTime: '06:22 AM – 08:40 AM',
      fastStartTime: '05:38 AM',
      description: 'Devaprabodhini description',
    ),
    EkadashiDate(
      id: 6,
      name: 'Utpanna Ekadashi',
      date: DateTime(2026, 11, 25),
      fastBreakTime: '06:28 AM – 08:45 AM',
      fastStartTime: '05:40 AM',
      description: 'Utpanna description',
    ),
  ];

  testWidgets('WidgetPreviewScreen displays exactly 3 compact cards with devotional lotus logo on the left',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageService>(
        create: (_) => LanguageService(),
        child: MaterialApp(
          home: WidgetPreviewScreen(
            ekadashiList: sampleEkadashis,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // ─── 1. AppBar title ─────────────────────────────────────────────────────
    expect(find.text('Ekadashi Calendar'), findsOneWidget);

    // ─── 2. Exactly 3 compact preview cards ──────────────────────────────────
    final card1Finder = find.byKey(const Key('card_today_ekadashi'));
    final card2Finder = find.byKey(const Key('card_next_ekadashi'));
    final card3Finder = find.byKey(const Key('card_upcoming_ekadashi'));

    expect(card1Finder, findsOneWidget);
    expect(card2Finder, findsOneWidget);
    expect(card3Finder, findsOneWidget);

    // ─── 3. Lotus Deity Logo on the LEFT of ALL 3 CARDS in Rounded-Corner Square Container ──
    final lotusLogoFinder = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/widget_lotus_deity.png' &&
          w.fit == BoxFit.contain,
    );
    // Exactly 3 lotus logos (one per card)
    expect(lotusLogoFinder, findsNWidgets(3));

    // Logo container shape: ClipRRect with moderate rounded corners (10dp)
    final logoClipFinder = find.byWidgetPredicate(
      (w) =>
          w is ClipRRect &&
          w.borderRadius == BorderRadius.circular(10) &&
          find.descendant(of: find.byWidget(w), matching: lotusLogoFinder).evaluate().isNotEmpty,
    );
    expect(logoClipFinder, findsNWidgets(3), reason: 'All 3 logo containers must be rounded-corner squares');

    // Card 1: Logo is to the left of "EKADASHI TODAY"
    final card1Logo = find.descendant(of: card1Finder, matching: lotusLogoFinder);
    final card1Text = find.descendant(of: card1Finder, matching: find.text('EKADASHI TODAY'));
    expect(card1Logo, findsOneWidget);
    expect(card1Text, findsOneWidget);
    expect(tester.getTopLeft(card1Logo).dx, lessThan(tester.getTopLeft(card1Text).dx));

    // Card 2: Logo is to the left of "NEXT EKADASHI"
    final card2Logo = find.descendant(of: card2Finder, matching: lotusLogoFinder);
    final card2Text = find.descendant(of: card2Finder, matching: find.text('NEXT EKADASHI'));
    expect(card2Logo, findsOneWidget);
    expect(card2Text, findsOneWidget);
    expect(find.descendant(of: card2Finder, matching: find.text('Starts in 2 days')), findsOneWidget);
    expect(tester.getTopLeft(card2Logo).dx, lessThan(tester.getTopLeft(card2Text).dx));

    // Card 3: Logo is to the left of "UPCOMING EKADASHI"
    final card3Logo = find.descendant(of: card3Finder, matching: lotusLogoFinder);
    final card3Text = find.descendant(of: card3Finder, matching: find.text('UPCOMING EKADASHI'));
    expect(card3Logo, findsOneWidget);
    expect(card3Text, findsOneWidget);
    expect(tester.getTopLeft(card3Logo).dx, lessThan(tester.getTopLeft(card3Text).dx));

    // Date boxes in Card 3
    expect(find.descendant(of: card3Finder, matching: find.text('OCT')), findsWidgets);
    expect(find.descendant(of: card3Finder, matching: find.text('11')), findsOneWidget);
    expect(find.descendant(of: card3Finder, matching: find.text('26')), findsOneWidget);
    expect(find.descendant(of: card3Finder, matching: find.text('NOV')), findsWidgets);
    expect(find.descendant(of: card3Finder, matching: find.text('10')), findsOneWidget);

    // ─── 4. Attached Background Banner Image behind content in ALL 3 CARDS ───
    final bannerFinder = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/widget_card_banner.png' &&
          w.fit == BoxFit.cover,
    );
    expect(bannerFinder, findsNWidgets(3), reason: 'All 3 cards must have the attached background banner image');

    // Opacity layer check (moderate subtle opacity 0.28)
    final bannerOpacityFinder = find.byWidgetPredicate(
      (w) =>
          w is Opacity &&
          w.opacity == 0.28 &&
          find.descendant(of: find.byWidget(w), matching: bannerFinder).evaluate().isNotEmpty,
    );
    expect(bannerOpacityFinder, findsNWidgets(3), reason: 'Banner must have reduced opacity for clear text visibility');

    // ─── 5. NO outer card outline / border / stroke ─────────────────────────
    final cardContainers = tester.widgetList<Container>(find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius ==
              BorderRadius.circular(16),
    ));
    expect(cardContainers.length, 3, reason: 'Must have exactly 3 preview cards with borderRadius=16');
    for (final container in cardContainers) {
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.border,
        isNull,
        reason: 'Module 13 spec: No card outline / border / stroke on outer cards',
      );
    }

    // ─── 5. Interactivity: Tap Card 1 -> DetailsScreen ───────────────────────
    await tester.tap(card1Finder);
    await tester.pumpAndSettle();
    expect(find.byType(DetailsScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(DetailsScreen))).pop();
    await tester.pumpAndSettle();

    // ─── 6. Interactivity: Tap Card 2 -> DetailsScreen ───────────────────────
    await tester.tap(card2Finder);
    await tester.pumpAndSettle();
    expect(find.byType(DetailsScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(DetailsScreen))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('WidgetPreviewScreen renders responsively on smaller mobile screens without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageService>(
        create: (_) => LanguageService(),
        child: MaterialApp(
          home: WidgetPreviewScreen(
            ekadashiList: sampleEkadashis,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ensure all 3 cards and their logos are present and no RenderFlex overflow
    expect(find.byKey(const Key('card_today_ekadashi')), findsOneWidget);
    expect(find.byKey(const Key('card_next_ekadashi')), findsOneWidget);
    expect(find.byKey(const Key('card_upcoming_ekadashi')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
