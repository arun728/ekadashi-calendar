import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/screens/widgets/parana_guidance_sheet.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/parana_guidance_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

Widget createParanaSheetApp({
  required LanguageService languageService,
  required TraditionService traditionService,
  AppTradition initialTradition = AppTradition.general,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeService()),
      ChangeNotifierProvider<LanguageService>.value(value: languageService),
      ChangeNotifierProvider<TraditionService>.value(value: traditionService),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ParanaGuidanceSheet(
          initialTradition: initialTradition,
          breakTime: '06:32 AM - 08:52 AM',
          timezone: 'IST',
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LanguageService languageService;
  late TraditionService traditionService;

  setUpAll(() async {
    final file = File('assets/parana_guidance.json');
    final rawJson = await file.readAsString();
    ParanaGuidanceService().loadFromJsonString(rawJson);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    languageService = LanguageService();
    traditionService = TraditionService();
    await languageService.changeLanguage('en');
    await traditionService.setTradition(AppTradition.general);
  });

  group('ParanaGuidanceSheet Widget Tests', () {
    testWidgets('Renders Header, Verification badges, and Sections', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createParanaSheetApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      // Header title
      expect(find.text('Parana Guidance'), findsOneWidget);

      // Dual badges: Astronomical calculation & Shastric ritual guidance
      expect(find.text('Astronomical Calculation'), findsOneWidget);
      expect(find.text('Canonical Ritual Guidance'), findsOneWidget);

      // Section titles
      expect(find.text('What is Parana?'), findsOneWidget);
      expect(find.text('Parana Window & Timings'), findsOneWidget);
      expect(find.textContaining('06:32 AM - 08:52 AM'), findsOneWidget);
      expect(find.text('Dwadashi Observance'), findsOneWidget);
      expect(find.text('If Parana Window is Missed'), findsOneWidget);
    });

    testWidgets('Tradition switching updates specific rule and source', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createParanaSheetApp(
        languageService: languageService,
        traditionService: traditionService,
        initialTradition: AppTradition.general,
      ));
      await tester.pumpAndSettle();

      // General mode initial check
      expect(find.text('General Parana Guidance'), findsOneWidget);

      // Switch to Vaishnava
      await tester.tap(find.text('Vaishnava'));
      await tester.pumpAndSettle();

      // Vaishnava rule card should appear with Haribhaktivilasa citation
      expect(find.text('Vaishnava Parana Guidance'), findsOneWidget);
      expect(find.textContaining('Haribhaktivilasa'), findsWidgets);

      // Switch to Smarta
      await tester.tap(find.text('Smarta'));
      await tester.pumpAndSettle();

      // Smarta rule card should appear with Dharma Sindhu citation
      expect(find.text('Smarta Parana Guidance'), findsOneWidget);
      expect(find.textContaining('Dharma Sindhu'), findsWidgets);
    });

    testWidgets('Renders localized text in Tamil and Hindi', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Test Tamil
      await languageService.changeLanguage('ta');
      await tester.pumpWidget(createParanaSheetApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('பாரணை வழிகாட்டல்'), findsOneWidget);
      expect(find.text('பாரணை என்றால் என்ன?'), findsOneWidget);
      expect(find.text('வானியல் கணக்கீடு'), findsOneWidget);
      expect(find.text('துவாதசி விரத அனுசரிப்பு'), findsOneWidget);

      // Test Hindi
      await languageService.changeLanguage('hi');
      await tester.pumpWidget(createParanaSheetApp(
        languageService: languageService,
        traditionService: traditionService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('पारण मार्गदर्शन'), findsOneWidget);
      expect(find.text('पारण क्या है?'), findsOneWidget);
      expect(find.text('खगोलीय गणना'), findsOneWidget);
      expect(find.text('द्वादशी व्रत नियम'), findsOneWidget);
    });

    testWidgets('Navigating from DetailsScreen opens ParanaGuidanceSheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleEkadashi = EkadashiDate(
        id: 1,
        name: 'Utpanna Ekadashi',
        date: DateTime(2026, 12, 5),
        fastStartTime: '06:15 AM',
        fastBreakTime: '06:15 AM - 09:30 AM',
        description: 'Birth of Goddess Ekadashi.',
        story: 'Story of Goddess Ekadashi.',
        fastingRules: 'Avoid all grains.',
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

      // Find Parana Guidance link
      final paranaLink = find.text('Parana Guidance');
      expect(paranaLink, findsOneWidget);

      // Tap on Parana Guidance link
      await tester.tap(paranaLink);
      await tester.pumpAndSettle();

      // Bottom sheet should be visible with Parana content and verification badges
      expect(find.text('What is Parana?'), findsOneWidget);
      expect(find.text('Astronomical Calculation'), findsOneWidget);
      expect(find.text('Canonical Ritual Guidance'), findsOneWidget);
    });
  });
}
