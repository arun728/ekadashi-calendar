import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/food_guide_screen.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/services/food_guide_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';

Widget createFoodGuideApp({
  required LanguageService languageService,
  required TraditionService traditionService,
  AppTradition? initialTradition,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeService()),
      ChangeNotifierProvider<LanguageService>.value(value: languageService),
      ChangeNotifierProvider<TraditionService>.value(value: traditionService),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: FoodGuideScreen(initialTradition: initialTradition),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LanguageService languageService;
  late TraditionService traditionService;

  setUpAll(() async {
    // Initialize dataset from file for test environment
    final file = File('assets/vrat_food_guide.json');
    final rawJson = await file.readAsString();
    FoodGuideService().loadFromJsonString(rawJson);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    languageService = LanguageService();
    traditionService = TraditionService();
    await languageService.changeLanguage('en');
    await traditionService.setTradition(AppTradition.general);
  });

  group('FoodGuideScreen Widget Tests', () {
    testWidgets('Renders AppBar, Search bar, Tradition filter, and Food items', (tester) async {
      await tester.pumpWidget(createFoodGuideApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      // Verify app bar title
      expect(find.text('Ekadashi Food Guide'), findsOneWidget);

      // Verify search field exists
      expect(find.byType(TextField), findsOneWidget);

      // Verify tradition filter chips exist
      expect(find.text('General'), findsAtLeastNWidgets(1));
      expect(find.text('Smarta'), findsAtLeastNWidgets(1));
      expect(find.text('Vaishnava'), findsAtLeastNWidgets(1));

      // Verify first food item is visible in list
      expect(find.text('Buckwheat Flour (Kuttu)'), findsOneWidget);
    });

    testWidgets('Search query filters items dynamically', (tester) async {
      await tester.pumpWidget(createFoodGuideApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      // Enter search query "Tapioca"
      await tester.enterText(find.byType(TextField), 'Tapioca');
      await tester.pumpAndSettle();

      // The food card should match
      expect(find.text('Tapioca Pearls (Sabudana)'), findsOneWidget);
      expect(find.text('Water Chestnut Flour (Singhara)'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Water Chestnut Flour (Singhara)'), findsOneWidget);
    });

    testWidgets('Tradition filter switching updates visible items', (tester) async {
      await tester.pumpWidget(createFoodGuideApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      // In General mode, search for mustard
      await tester.enterText(find.byType(TextField), 'Mustard');
      await tester.pumpAndSettle();

      // Not found in General
      expect(find.text('Mustard Seeds & Mustard Oil (Rai / Sarson)'), findsNothing);

      // Switch to Vaishnava tradition chip
      await tester.tap(find.text('Vaishnava'));
      await tester.pumpAndSettle();

      // In Vaishnava, mustard seeds should now be displayed
      expect(find.text('Mustard Seeds & Mustard Oil (Rai / Sarson)'), findsOneWidget);
      expect(find.textContaining('orthodox Vaishnava'), findsOneWidget);
    });

    testWidgets('Category chips filter by category', (tester) async {
      await tester.pumpWidget(createFoodGuideApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      // Tap "Dairy & Fruits" category chip
      final dairyChip = find.text('Dairy & Fruits');
      expect(dairyChip, findsOneWidget);
      await tester.tap(dairyChip);
      await tester.pumpAndSettle();

      // Should find dairy items, but not flour items
      expect(find.textContaining('Cow Milk'), findsOneWidget);
      expect(find.text('Buckwheat Flour (Kuttu)'), findsNothing);
    });

    testWidgets('Food Guide renders in Tamil and Hindi properly', (tester) async {
      // Test Tamil
      await languageService.changeLanguage('ta');
      await tester.pumpWidget(createFoodGuideApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      // Tamil title
      expect(find.text('ஏகாதசி விரத உணவு வழிகாட்டி'), findsOneWidget);
      // Tamil category chip
      expect(find.text('அனைத்தும்'), findsOneWidget);

      // Test Hindi
      await languageService.changeLanguage('hi');
      await tester.pumpWidget(createFoodGuideApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      // Hindi title
      expect(find.text('एकादशी व्रत भोजन मार्गदर्शिका'), findsOneWidget);
      // Hindi category chip
      expect(find.text('सभी वस्तुएं'), findsOneWidget);
    });

    testWidgets('Navigation from DetailsScreen to FoodGuideScreen', (tester) async {
      final sampleEkadashi = EkadashiDate(
        id: 1,
        name: 'Utpanna Ekadashi',
        date: DateTime(2026, 12, 5),
        fastStartTime: '06:15 AM',
        fastBreakTime: '06:15 AM - 09:30 AM',
        description: 'Birth of Goddess Ekadashi.',
        story: 'Story of Murasura and Lord Vishnu.',
        fastingRules: 'Avoid all grains, cereals, and pulses.',
        benefits: 'Freedom from all sins.',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider<LanguageService>.value(value: languageService),
            ChangeNotifierProvider<TraditionService>.value(value: traditionService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: DetailsScreen(ekadashi: sampleEkadashi, timezone: 'IST'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag to scroll down to Fasting Rules section
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();

      // Verify "View Food Guide" button is visible in Fasting Rules section
      final foodGuideBtn = find.text('View Food Guide');
      expect(foodGuideBtn, findsOneWidget);

      // Tap on View Food Guide button
      await tester.tap(foodGuideBtn);
      await tester.pumpAndSettle();

      // Verify we arrived at FoodGuideScreen
      expect(find.text('Ekadashi Food Guide'), findsOneWidget);
      expect(find.byType(FoodGuideScreen), findsOneWidget);
    });
  });
}
