import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/screens/details_screen.dart';
import 'package:ekadashi_calendar/screens/widgets/tradition_variant_sheet.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/theme_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

Widget createDetailsApp({
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
    fastingRules: 'Smarta standard fasting rules',
    source: 'Drik Panchang Verified',
  );

  final vaishnavaVariant = TraditionVariant(
    tradition: AppTradition.vaishnava,
    date: DateTime(2026, 2, 14),
    fastStartTime: '06:31 AM',
    fastBreakTime: '06:31 AM - 10:15 AM',
    fastingRules: 'Vaishnava Dvadashi fasting rules',
    source: 'Vaishnava Calendar Verified',
  );

  final ekadashiWithVariation = EkadashiDate(
    id: 3,
    name: 'Vijaya Ekadashi',
    date: DateTime(2026, 2, 13),
    fastStartTime: '06:32 AM',
    fastBreakTime: '06:32 AM - 08:52 AM',
    description: 'Victory Ekadashi grants triumph over obstacles.',
    story: 'Lord Rama observed Vijaya Ekadashi before crossing the ocean to Lanka.',
    fastingRules: 'Observe full day fast with night vigil and Vishnu Kalash puja.',
    benefits: 'Grants victory in difficult undertakings.',
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
    description: 'Sesame seeds purification day.',
    story: 'The story of charity and the woman who offered clay.',
    fastingRules: 'Six uses of til/sesame seeds.',
    benefits: 'Purification and spiritual merit.',
    traditionVariants: const {},
    hasTraditionVariation: false,
  );

  testWidgets('DetailsScreen displays stories, fasting rules, and parana guidance', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final lang = LanguageService();
    final ts = TraditionService();

    await tester.pumpWidget(createDetailsApp(
      ekadashi: ekadashiWithoutVariation,
      languageService: lang,
      traditionService: ts,
    ));
    await tester.pumpAndSettle();

    // Significance / Description
    expect(find.text('Significance'), findsOneWidget);
    expect(find.text('Sesame seeds purification day.'), findsOneWidget);

    // Story / Katha
    expect(find.text('Story and History'), findsOneWidget);
    expect(find.text('The story of charity and the woman who offered clay.'), findsOneWidget);

    // Fasting Rules
    expect(find.text('Fasting Rules'), findsOneWidget);
    expect(find.text('Six uses of til/sesame seeds.'), findsOneWidget);

    // Timings & Parana guidance
    expect(find.text('Start Fasting'), findsOneWidget);
    expect(find.text('06:35 AM'), findsOneWidget);
    expect(find.text('Break Fasting'), findsOneWidget);
    expect(find.text('06:35 AM - 08:52 AM'), findsOneWidget);
  });

  testWidgets('Hides alternative-date button when no variation exists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final lang = LanguageService();
    final ts = TraditionService();

    await tester.pumpWidget(createDetailsApp(
      ekadashi: ekadashiWithoutVariation,
      languageService: lang,
      traditionService: ts,
    ));
    await tester.pumpAndSettle();

    expect(find.text("View other tradition's date"), findsNothing);
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
  });

  testWidgets('Displays alternative-date button and opens bottom sheet when variation exists', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'user_tradition': 'smarta'});
    final lang = LanguageService();
    final ts = TraditionService();
    await ts.loadTradition();

    await tester.pumpWidget(createDetailsApp(
      ekadashi: ekadashiWithVariation,
      languageService: lang,
      traditionService: ts,
    ));
    await tester.pumpAndSettle();

    // Verify button exists
    final altButton = find.text("View other tradition's date");
    expect(altButton, findsOneWidget);

    // Tap the button
    await tester.tap(altButton);
    await tester.pumpAndSettle();

    // Bottom sheet is displayed
    expect(find.byType(TraditionVariantSheet), findsOneWidget);
    expect(find.textContaining('Alternate Tradition'), findsOneWidget);
    expect(find.textContaining('Vaishnava'), findsWidgets);
    expect(find.text('Vaishnava Dvadashi fasting rules'), findsOneWidget);
  });

  testWidgets('DetailsScreen localized correctly in Tamil', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'ta', 'user_tradition': 'smarta'});
    final lang = LanguageService();
    await lang.changeLanguage('ta');
    final ts = TraditionService();
    await ts.loadTradition();

    await tester.pumpWidget(createDetailsApp(
      ekadashi: ekadashiWithVariation,
      languageService: lang,
      traditionService: ts,
    ));
    await tester.pumpAndSettle();

    expect(find.text('சிறப்பு'), findsOneWidget);
    expect(find.text('கதை மற்றும் வரலாறு'), findsOneWidget);
    expect(find.text('விரத விதிமுறைகள்'), findsOneWidget);
    expect(find.text('பிற மரபின் தேதியைக் காண்க'), findsOneWidget);
  });

  testWidgets('DetailsScreen localized correctly in Hindi', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'hi', 'user_tradition': 'smarta'});
    final lang = LanguageService();
    await lang.changeLanguage('hi');
    final ts = TraditionService();
    await ts.loadTradition();

    await tester.pumpWidget(createDetailsApp(
      ekadashi: ekadashiWithVariation,
      languageService: lang,
      traditionService: ts,
    ));
    await tester.pumpAndSettle();

    expect(find.text('महत्व'), findsOneWidget);
    expect(find.text('कथा और इतिहास'), findsOneWidget);
    expect(find.text('व्रत के नियम'), findsOneWidget);
    expect(find.text('अन्य परंपरा की तिथि देखें'), findsOneWidget);
  });
}
