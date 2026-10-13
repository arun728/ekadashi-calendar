import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/screens/widgets/tradition_variant_sheet.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

Widget createTestDetailsApp({
  required EkadashiDate ekadashi,
  required LanguageService languageService,
  required TraditionService traditionService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeService()),
      ChangeNotifierProvider<LanguageService>.value(value: languageService),
      ChangeNotifierProvider<TraditionService>.value(value: traditionService),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: DetailsScreen(ekadashi: ekadashi, timezone: 'IST'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final smartaVariant = TraditionVariant(
    tradition: AppTradition.smarta,
    date: DateTime(2026, 2, 13),
    fastStartTime: '06:32 AM',
    fastBreakTime: '06:32 AM - 08:52 AM',
    fastingRules: 'Smarta vigil and sunrise rules.',
    source: 'Drik Panchang Verified',
  );

  final vaishnavaVariant = TraditionVariant(
    tradition: AppTradition.vaishnava,
    date: DateTime(2026, 2, 14),
    fastStartTime: '06:31 AM',
    fastBreakTime: '06:31 AM - 10:15 AM',
    fastingRules: 'Vaishnava Shuddha Ekadashi rules.',
    source: 'Vaishnava Calendar Verified',
  );

  final ekadashiWithVariation = EkadashiDate(
    id: 3,
    name: 'Vijaya Ekadashi',
    date: DateTime(2026, 2, 13),
    fastStartTime: '06:32 AM',
    fastBreakTime: '06:32 AM - 08:52 AM',
    description: 'Victory Ekadashi description.',
    story: 'Story of Lord Rama.',
    fastingRules: 'General Vijaya fasting rules.',
    benefits: 'Victory in all tasks.',
    traditionVariants: {
      AppTradition.smarta: smartaVariant,
      AppTradition.vaishnava: vaishnavaVariant,
    },
    hasTraditionVariation: true,
  );

  final ekadashiWithoutVariation = EkadashiDate(
    id: 1,
    name: 'Shattila Ekadashi',
    date: DateTime(2026, 1, 14),
    fastStartTime: '06:35 AM',
    fastBreakTime: '06:35 AM - 08:52 AM',
    description: 'Purification with sesame seeds.',
    story: 'Story of charity.',
    fastingRules: 'Six uses of sesame seeds.',
    benefits: 'Purification merit.',
    traditionVariants: const {},
    hasTraditionVariation: false,
  );

  final ekadashiWithMissingRules = EkadashiDate(
    id: 99,
    name: 'Test Ekadashi Missing Rules',
    date: DateTime(2026, 5, 10),
    fastStartTime: '06:00 AM',
    fastBreakTime: '06:00 AM - 09:00 AM',
    description: 'Test description.',
    story: 'Test story.',
    fastingRules: '', // Missing / unverified
    benefits: 'Test benefits.',
    traditionVariants: {
      AppTradition.smarta: TraditionVariant(
        tradition: AppTradition.smarta,
        date: DateTime(2026, 5, 10),
        fastStartTime: '06:00 AM',
        fastBreakTime: '06:00 AM - 09:00 AM',
        fastingRules: '', // Missing
      ),
      AppTradition.vaishnava: TraditionVariant(
        tradition: AppTradition.vaishnava,
        date: DateTime(2026, 5, 11),
        fastStartTime: '06:00 AM',
        fastBreakTime: '06:00 AM - 09:00 AM',
        fastingRules: '', // Missing
      ),
    },
    hasTraditionVariation: true,
  );

  group('Module 11 Area 2: Tradition-Aware Fasting Rules UI & Logic Tests', () {
    testWidgets('General preference displays general fasting rules and General badge', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'user_tradition': 'general'});
      final lang = LanguageService();
      final ts = TraditionService();
      await ts.loadTradition();

      await tester.pumpWidget(createTestDetailsApp(
        ekadashi: ekadashiWithVariation,
        languageService: lang,
        traditionService: ts,
      ));
      await tester.pumpAndSettle();

      // Should display general fasting rules and General badge
      expect(find.text('General'), findsWidgets);
      expect(find.text('General Vijaya fasting rules.'), findsOneWidget);
      // Access to other tradition rules should be present
      expect(find.text("View other tradition's fasting rules"), findsOneWidget);
    });

    testWidgets('Smarta preference displays Smarta fasting rules and Smarta badge', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'user_tradition': 'smarta'});
      final lang = LanguageService();
      final ts = TraditionService();
      await ts.loadTradition();

      await tester.pumpWidget(createTestDetailsApp(
        ekadashi: ekadashiWithVariation,
        languageService: lang,
        traditionService: ts,
      ));
      await tester.pumpAndSettle();

      // Should display Smarta fasting rules
      expect(find.text('Smarta'), findsWidgets);
      expect(find.text('Smarta vigil and sunrise rules.'), findsOneWidget);
      expect(find.text("View other tradition's fasting rules"), findsOneWidget);
    });

    testWidgets('Vaishnava preference displays Vaishnava fasting rules and Vaishnava badge', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'user_tradition': 'vaishnava'});
      final lang = LanguageService();
      final ts = TraditionService();
      await ts.loadTradition();

      await tester.pumpWidget(createTestDetailsApp(
        ekadashi: ekadashiWithVariation,
        languageService: lang,
        traditionService: ts,
      ));
      await tester.pumpAndSettle();

      // Should display Vaishnava fasting rules
      expect(find.text('Vaishnava'), findsWidgets);
      expect(find.text('Vaishnava Shuddha Ekadashi rules.'), findsOneWidget);
      expect(find.text("View other tradition's fasting rules"), findsOneWidget);
    });

    testWidgets('Fasting rules without variation display no alternate-rules button', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'user_tradition': 'smarta'});
      final lang = LanguageService();
      final ts = TraditionService();
      await ts.loadTradition();

      await tester.pumpWidget(createTestDetailsApp(
        ekadashi: ekadashiWithoutVariation,
        languageService: lang,
        traditionService: ts,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Six uses of sesame seeds.'), findsOneWidget);
      expect(find.text("View other tradition's fasting rules"), findsNothing);
    });

    testWidgets('Tapping view_other_tradition_rules opens bottom sheet with both guidance sections', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'user_tradition': 'smarta'});
      final lang = LanguageService();
      final ts = TraditionService();
      await ts.loadTradition();

      await tester.pumpWidget(createTestDetailsApp(
        ekadashi: ekadashiWithVariation,
        languageService: lang,
        traditionService: ts,
      ));
      await tester.pumpAndSettle();

      final altRulesButton = find.text("View other tradition's fasting rules");
      expect(altRulesButton, findsOneWidget);
      await tester.tap(altRulesButton);
      await tester.pumpAndSettle();

      // Bottom sheet appears
      expect(find.byType(TraditionVariantSheet), findsOneWidget);
      // Both Smarta and Vaishnava guidance must be visible in sheet
      expect(find.descendant(of: find.byType(TraditionVariantSheet), matching: find.text('Smarta vigil and sunrise rules.')), findsOneWidget);
      expect(find.descendant(of: find.byType(TraditionVariantSheet), matching: find.text('Vaishnava Shuddha Ekadashi rules.')), findsOneWidget);
    });

    testWidgets('Missing/unverified fasting rules fallback safely to pending verification message', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'user_tradition': 'smarta'});
      final lang = LanguageService();
      final ts = TraditionService();
      await ts.loadTradition();

      await tester.pumpWidget(createTestDetailsApp(
        ekadashi: ekadashiWithMissingRules,
        languageService: lang,
        traditionService: ts,
      ));
      await tester.pumpAndSettle();

      // Must display pending message, never invent rules
      expect(find.text('Tradition-specific fasting guidance pending verification.'), findsOneWidget);
    });

    testWidgets('DetailsScreen fasting rules localization in Tamil', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'language_code': 'ta', 'user_tradition': 'smarta'});
      final lang = LanguageService();
      await lang.changeLanguage('ta');
      final ts = TraditionService();
      await ts.loadTradition();

      await tester.pumpWidget(createTestDetailsApp(
        ekadashi: ekadashiWithVariation,
        languageService: lang,
        traditionService: ts,
      ));
      await tester.pumpAndSettle();

      expect(find.text('விரத விதிமுறைகள்'), findsOneWidget);
      expect(find.text('ஸ்மார்த்தா'), findsWidgets);
      expect(find.text('பிற மரபின் விரத விதிகளைக் காண்க'), findsOneWidget);
    });

    testWidgets('DetailsScreen fasting rules localization in Hindi', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'language_code': 'hi', 'user_tradition': 'vaishnava'});
      final lang = LanguageService();
      await lang.changeLanguage('hi');
      final ts = TraditionService();
      await ts.loadTradition();

      await tester.pumpWidget(createTestDetailsApp(
        ekadashi: ekadashiWithVariation,
        languageService: lang,
        traditionService: ts,
      ));
      await tester.pumpAndSettle();

      expect(find.text('व्रत के नियम'), findsOneWidget);
      expect(find.text('वैष्णव'), findsWidgets);
      expect(find.text('अन्य परंपरा के व्रत नियम देखें'), findsOneWidget);
    });

    test('All Area 2 localization keys exist and are non-empty in en, ta, and hi', () {
      final lang = LanguageService();
      const languages = ['en', 'ta', 'hi', 'te'];
      const requiredKeys = [
        'fasting_rules_smarta',
        'fasting_rules_vaishnava',
        'fasting_rules_general',
        'view_other_tradition_rules',
        'fasting_rules_pending',
        'rules_differ_note',
      ];

      for (var code in languages) {
        lang.changeLanguage(code);
        for (var key in requiredKeys) {
          final translated = lang.translate(key);
          expect(translated, isNotEmpty, reason: 'Key $key in $code should not be empty');
          expect(translated, isNot(equals(key)), reason: 'Key $key in $code should have a valid translation');
        }
      }
    });

    test('Verification that 2026–2027 event dates and IDs remain unchanged', () async {
      final jsonString = await rootBundle.loadString('assets/ekadashi_data.json');
      final data = json.decode(jsonString);
      final ekadashis = data['ekadashis'] as List;

      expect(ekadashis.length, equals(49), reason: 'Total 49 events for 2026 and 2027 must remain intact');
      expect(data['date_range']['start'], equals('2026-01-01'));
      expect(data['date_range']['end'], equals('2027-12-31'));

      final ids = ekadashis.map((e) => e['id'] as int).toList();
      for (int i = 1; i <= 49; i++) {
        expect(ids.contains(i), isTrue, reason: 'ID $i must exist');
      }

      // Check 2026 first event
      expect(ekadashis[0]['timing']['IST']['date'], equals('2026-01-14'));
      // Check 2027 last event (Event #49: Saphala Ekadashi)
      expect(ekadashis[48]['timing']['IST']['date'], equals('2027-12-23'));
    });
  });
}
