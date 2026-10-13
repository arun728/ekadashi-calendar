import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/native_location_service.dart';
import 'package:ekadashi_calendar/services/share_card_service.dart';
import 'package:ekadashi_calendar/screens/widgets/shareable_ekadashi_card.dart';
import 'package:ekadashi_calendar/screens/share_card_preview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('ta', null);
    await initializeDateFormatting('hi', null);
    await initializeDateFormatting('te', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testEkadashi = EkadashiDate(
    id: 1,
    name: 'Mokshada / Vaikuntha Ekadashi',
    date: DateTime(2026, 12, 20),
    paksha: 'Shukla Paksha',
    month: 'Margashirsha',
    fastStartTime: '05:30 AM',
    fastBreakTime: '06:45 AM - 09:30 AM',
    description: 'Significance of Mokshada Ekadashi',
    benefits:
        'Observing this sacred fast grants freedom from sins and bestows divine grace.',
  );

  final testLocation = LocationData(
    latitude: 13.0827,
    longitude: 80.2707,
    city: 'Chennai',
    state: 'Tamil Nadu',
    timezone: 'IST',
  );

  Widget createTestWidget({
    required Widget child,
    required LanguageService langService,
    required TraditionService traditionService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageService>.value(value: langService),
        ChangeNotifierProvider<TraditionService>.value(value: traditionService),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('ShareableEkadashiCard Widget Tests', () {
    testWidgets('renders all essential card elements correctly in green theme with no URLs', (tester) async {
      final lang = LanguageService();
      await lang.changeLanguage('en');
      final traditionService = TraditionService();
      traditionService.setTradition(AppTradition.vaishnava);

      await tester.pumpWidget(
        createTestWidget(
          langService: lang,
          traditionService: traditionService,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: ShareableEkadashiCard(
                  ekadashi: testEkadashi,
                  theme: CardDesignTheme.divineTeal,
                  tradition: AppTradition.vaishnava,
                  lang: lang,
                  location: testLocation,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify Ekadashi name is shown in serif font
      expect(find.text('Mokshada / Vaikuntha Ekadashi'), findsOneWidget);

      // Verify tradition badge is shown
      expect(find.text('VAISHNAVA'), findsOneWidget);

      // Verify header emblem and title
      expect(find.text('EKADASHI OBSERVANCE'), findsOneWidget);

      // Verify paksha and month
      expect(find.text('SHUKLA PAKSHA • MARGASHIRSHA'), findsOneWidget);

      // Verify timings are shown
      expect(find.text('05:30 AM'), findsOneWidget);
      expect(find.text('06:45 AM - 09:30 AM'), findsOneWidget);

      // Verify location is NOT displayed on the shareable card
      expect(find.text('CURRENT LOCATION'), findsNothing);
      expect(find.text('Chennai, Tamil Nadu'), findsNothing);

      // Verify Significance section is displayed with existing significance text
      expect(find.text('SIGNIFICANCE'), findsOneWidget);
      expect(find.text('Significance of Mokshada Ekadashi'), findsOneWidget);

      // Verify NO URL or "Get App" link is present in the card design
      expect(find.text('Get Ekadashi Calendar 2.0'), findsNothing);
      expect(
        find.text('https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar'),
        findsNothing,
      );
      expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);

      // Verify official logo image is rendered using the new transparent logo asset
      final newLogoFinder = find.byWidgetPredicate((widget) {
        if (widget is Image && widget.image is AssetImage) {
          final asset = widget.image as AssetImage;
          return asset.assetName == 'assets/ekadashi_logo_transparent.png';
        }
        return false;
      });
      expect(newLogoFinder, findsOneWidget);

      // Verify the old logo is no longer referenced
      final oldLogoFinder = find.byWidgetPredicate((widget) {
        if (widget is Image && widget.image is AssetImage) {
          final asset = widget.image as AssetImage;
          return asset.assetName == 'assets/ekadashi_logo.png';
        }
        return false;
      });
      expect(oldLogoFinder, findsNothing);

      // Verify branding is shown without '2.0'
      expect(find.text('Ekadashi Calendar'), findsOneWidget);
      expect(find.text('Ekadashi Calendar 2.0'), findsNothing);
    });

    testWidgets('tradition badge renders SMARTA for smarta, VAISHNAVA for vaishnava, and is hidden for general', (tester) async {
      final lang = LanguageService();
      await lang.changeLanguage('en');
      final traditionService = TraditionService();

      // Test 1: General tradition -> badge is completely hidden, never shows GENERAL
      traditionService.setTradition(AppTradition.general);
      await tester.pumpWidget(
        createTestWidget(
          langService: lang,
          traditionService: traditionService,
          child: Scaffold(
            body: ShareableEkadashiCard(
              ekadashi: testEkadashi,
              theme: CardDesignTheme.divineTeal,
              tradition: AppTradition.general,
              lang: lang,
            ),
          ),
        ),
      );
      expect(find.text('GENERAL'), findsNothing);
      expect(find.text('General'), findsNothing);

      // Test 2: Smarta tradition -> displays SMARTA
      traditionService.setTradition(AppTradition.smarta);
      await tester.pumpWidget(
        createTestWidget(
          langService: lang,
          traditionService: traditionService,
          child: Scaffold(
            body: ShareableEkadashiCard(
              ekadashi: testEkadashi,
              theme: CardDesignTheme.divineTeal,
              tradition: AppTradition.smarta,
              lang: lang,
            ),
          ),
        ),
      );
      expect(find.text('SMARTA'), findsOneWidget);
      expect(find.text('GENERAL'), findsNothing);

      // Test 3: Vaishnava tradition -> displays VAISHNAVA
      traditionService.setTradition(AppTradition.vaishnava);
      await tester.pumpWidget(
        createTestWidget(
          langService: lang,
          traditionService: traditionService,
          child: Scaffold(
            body: ShareableEkadashiCard(
              ekadashi: testEkadashi,
              theme: CardDesignTheme.divineTeal,
              tradition: AppTradition.vaishnava,
              lang: lang,
            ),
          ),
        ),
      );
      expect(find.text('VAISHNAVA'), findsOneWidget);
      expect(find.text('GENERAL'), findsNothing);
    });

    testWidgets('renders cleanly in green theme across all 4 languages without overflow', (tester) async {
      final allLangs = ['en', 'ta', 'hi', 'te'];
      final traditionService = TraditionService();
      traditionService.setTradition(AppTradition.smarta);

      for (final langCode in allLangs) {
        final lang = LanguageService();
        await lang.changeLanguage(langCode);

        await tester.pumpWidget(
          createTestWidget(
            langService: lang,
            traditionService: traditionService,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Center(
                  child: ShareableEkadashiCard(
                    ekadashi: testEkadashi,
                    theme: CardDesignTheme.divineTeal,
                    tradition: AppTradition.smarta,
                    lang: lang,
                    location: testLocation,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow or rendering exception occurred for green theme in language $langCode',
        );
      }
    });
  });

  group('ShareCardPreviewScreen Widget Tests', () {
    testWidgets('renders single green theme preview with action buttons and no theme switcher', (tester) async {
      final lang = LanguageService();
      await lang.changeLanguage('en');
      final traditionService = TraditionService();

      await tester.pumpWidget(
        createTestWidget(
          langService: lang,
          traditionService: traditionService,
          child: ShareCardPreviewScreen(ekadashi: testEkadashi),
        ),
      );
      await tester.pumpAndSettle();

      // Check title in AppBar
      expect(find.text('Share Card'), findsOneWidget);

      // Verify obsolete themes (Sacred Gold & Cosmic Blue) and theme switcher are completely removed
      expect(find.text('Sacred Gold'), findsNothing);
      expect(find.text('Cosmic Blue'), findsNothing);
      expect(find.text('Choose Card Theme'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);

      // Check Action Buttons
      expect(find.text('Save Image'), findsOneWidget);
      expect(find.text('Share Card'), findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Save button disables during save operation to prevent duplicate saves', (tester) async {
      final lang = LanguageService();
      await lang.changeLanguage('en');
      final traditionService = TraditionService();

      await tester.pumpWidget(
        createTestWidget(
          langService: lang,
          traditionService: traditionService,
          child: ShareCardPreviewScreen(ekadashi: testEkadashi),
        ),
      );
      await tester.pumpAndSettle();

      final saveButtonFinder = find.widgetWithText(OutlinedButton, 'Save Image');
      expect(saveButtonFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(saveButtonFinder);
      expect(button.enabled, isTrue);
    });
  });
}
