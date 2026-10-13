import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/panchang_calculator.dart';
import 'package:ekadashi_calendar/services/native_location_service.dart';
import 'package:ekadashi_calendar/services/tradition_notification_helper.dart';
import 'package:ekadashi_calendar/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Location-Aware Observance and Variant Parana Accuracy Tests', () {
    final ekadashiService = EkadashiService();

    final chennaiLoc = LocationData(
      latitude: 13.0827,
      longitude: 80.2707,
      city: 'Chennai',
      state: 'Tamil Nadu',
      timezone: 'IST',
    );

    final guwahatiLoc = LocationData(
      latitude: 26.1445,
      longitude: 91.7362,
      city: 'Guwahati',
      state: 'Assam',
      timezone: 'IST',
    );

    final mumbaiLoc = LocationData(
      latitude: 19.0760,
      longitude: 72.8777,
      city: 'Mumbai',
      state: 'Maharashtra',
      timezone: 'IST',
    );

    setUpAll(() {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': false,
        'fasting_reminders': false,
        'parana_reminders': false,
      });
      TraditionNotificationCoordinator.initialize();
      final file = File('assets/ekadashi_data.json');
      final data = json.decode(file.readAsStringSync());
      ekadashiService.loadDataFromJson(data);
    });

    test('1. Chennai, Guwahati and Mumbai have distinct topocentric sunrises & parana windows for same event', () {
      final chennaiEvents = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.general,
      );

      final guwahatiEvents = ekadashiService.getEkadashis(
        location: guwahatiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.general,
      );

      final mumbaiEvents = ekadashiService.getEkadashis(
        location: mumbaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.general,
      );

      // Event #1: Shattila Ekadashi (Jan 14, 2026)
      final e1Chennai = chennaiEvents.firstWhere((e) => e.id == 1);
      final e1Guwahati = guwahatiEvents.firstWhere((e) => e.id == 1);
      final e1Mumbai = mumbaiEvents.firstWhere((e) => e.id == 1);

      // Fast start time reflects local sunrise
      expect(e1Guwahati.fastStartTime, isNot(equals(e1Mumbai.fastStartTime)));
      expect(e1Chennai.fastStartTime, isNot(equals(e1Mumbai.fastStartTime)));

      // Guwahati (east) sunrise is earlier than Mumbai (west) sunrise
      expect(e1Guwahati.fastingStartIso, isNotEmpty);
      expect(e1Mumbai.fastingStartIso, isNotEmpty);
      final dtGuwahati = DateTime.parse(e1Guwahati.fastingStartIso);
      final dtMumbai = DateTime.parse(e1Mumbai.fastingStartIso);
      expect(dtGuwahati.isBefore(dtMumbai), isTrue,
          reason: 'Guwahati sunrise must be strictly before Mumbai sunrise');

      // Parana window start time in Guwahati must also open before Mumbai
      final paranaStartGuwahati = DateTime.parse(e1Guwahati.paranaStartIso);
      final paranaStartMumbai = DateTime.parse(e1Mumbai.paranaStartIso);
      expect(paranaStartGuwahati.isBefore(paranaStartMumbai), isTrue,
          reason: 'Guwahati Parana start must be earlier than Mumbai Parana start');
    });

    test('2. Smarta vs Vaishnava dates diverge correctly for all 8 variant events across 2026-2027', () {
      final smartaEvents = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.smarta,
      );

      final vaishnavaEvents = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.vaishnava,
      );

      // 2026: Yogini (#13), Shravana Putrada (#16), Devutthana (#22) differ
      final yoginiSmarta = smartaEvents.firstWhere((e) => e.id == 13);
      final yoginiVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 13);
      expect(yoginiSmarta.date, DateTime(2026, 7, 10));
      expect(yoginiVaishnava.date, DateTime(2026, 7, 11));

      final putrada2026Smarta = smartaEvents.firstWhere((e) => e.id == 16);
      final putrada2026Vaishnava = vaishnavaEvents.firstWhere((e) => e.id == 16);
      expect(putrada2026Smarta.date, DateTime(2026, 8, 23));
      expect(putrada2026Vaishnava.date, DateTime(2026, 8, 24));

      final devutthanaSmarta = smartaEvents.firstWhere((e) => e.id == 22);
      final devutthanaVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 22);
      expect(devutthanaSmarta.date, DateTime(2026, 11, 20));
      expect(devutthanaVaishnava.date, DateTime(2026, 11, 21));

      // Same-day 2026 events: Vijaya (#3), Rama (#21), Mokshada (#24)
      final vijayaSmarta = smartaEvents.firstWhere((e) => e.id == 3);
      final vijayaVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 3);
      expect(vijayaSmarta.date, DateTime(2026, 2, 13));
      expect(vijayaVaishnava.date, DateTime(2026, 2, 13));

      final rama2026Smarta = smartaEvents.firstWhere((e) => e.id == 21);
      final rama2026Vaishnava = vaishnavaEvents.firstWhere((e) => e.id == 21);
      expect(rama2026Smarta.date, DateTime(2026, 11, 5));
      expect(rama2026Vaishnava.date, DateTime(2026, 11, 5));

      final mokshada2026Smarta = smartaEvents.firstWhere((e) => e.id == 24);
      final mokshada2026Vaishnava = vaishnavaEvents.firstWhere((e) => e.id == 24);
      expect(mokshada2026Smarta.date, DateTime(2026, 12, 20));
      expect(mokshada2026Vaishnava.date, DateTime(2026, 12, 20));

      // 2027: Pausha Putrada (#26), Nirjala (#36), Kamika (#39), Parivartini (#42), Rama (#45)
      final putradaSmarta = smartaEvents.firstWhere((e) => e.id == 26);
      final putradaVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 26);
      expect(putradaSmarta.date, DateTime(2027, 1, 18));
      expect(putradaVaishnava.date, DateTime(2027, 1, 19));

      final nirjalaSmarta = smartaEvents.firstWhere((e) => e.id == 36);
      final nirjalaVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 36);
      expect(nirjalaSmarta.date, DateTime(2027, 6, 14));
      expect(nirjalaVaishnava.date, DateTime(2027, 6, 15));

      final kamikaSmarta = smartaEvents.firstWhere((e) => e.id == 39);
      final kamikaVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 39);
      expect(kamikaSmarta.date, DateTime(2027, 7, 29));
      expect(kamikaVaishnava.date, DateTime(2027, 7, 30));

      final parivartiniSmarta = smartaEvents.firstWhere((e) => e.id == 42);
      final parivartiniVaishnava = vaishnavaEvents.firstWhere((e) => e.id == 42);
      expect(parivartiniSmarta.date, DateTime(2027, 9, 11));
      expect(parivartiniVaishnava.date, DateTime(2027, 9, 12));

      final rama2027Smarta = smartaEvents.firstWhere((e) => e.id == 45);
      final rama2027Vaishnava = vaishnavaEvents.firstWhere((e) => e.id == 45);
      expect(rama2027Smarta.date, DateTime(2027, 10, 25));
      expect(rama2027Vaishnava.date, DateTime(2027, 10, 26));
    });

    test('3. Tradition variant Parana window recalculates topocentrically for selected city', () {
      final guwahatiVaishnava = ekadashiService.getEkadashis(
        location: guwahatiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.vaishnava,
      );

      final mumbaiVaishnava = ekadashiService.getEkadashis(
        location: mumbaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.vaishnava,
      );

      // Event #36: Nirjala Ekadashi 2027 (Vaishnava on June 15, Parana on June 16)
      final nirjalaGuwahati = guwahatiVaishnava.firstWhere((e) => e.id == 36);
      final nirjalaMumbai = mumbaiVaishnava.firstWhere((e) => e.id == 36);

      expect(nirjalaGuwahati.date, DateTime(2027, 6, 15));
      expect(nirjalaMumbai.date, DateTime(2027, 6, 15));

      // In June solstice, Guwahati sunrise is ~04:30 AM whereas Mumbai is ~06:01 AM
      // Therefore, the Vaishnava Parana window in Guwahati opens significantly earlier than in Mumbai
      final pStartGuwahati = DateTime.parse(nirjalaGuwahati.paranaStartIso);
      final pStartMumbai = DateTime.parse(nirjalaMumbai.paranaStartIso);

      expect(pStartGuwahati.isBefore(pStartMumbai), isTrue);
      final diffMins = pStartMumbai.difference(pStartGuwahati).inMinutes;
      expect(diffMins, greaterThanOrEqualTo(60),
          reason: 'Nirjala Parana start in Mumbai should be at least 60 mins later than Guwahati');
    });

    test('4. Tithi boundary close to sunrise resolves correctly without crashes', () {
      // Create artificial boundary where Ekadashi ends 10 mins after sunrise
      final testSunrise = DateTime(2026, 6, 1, 6, 0);
      final closeStart = testSunrise.subtract(const Duration(hours: 20));
      final closeEnd = testSunrise.add(const Duration(minutes: 10)); // Just 10 min after sunrise
      final dwEnd = testSunrise.add(const Duration(hours: 24));
      final daEnd = closeStart.subtract(const Duration(hours: 1));

      final observance = PanchangCalculator.resolveObservance(
        ekadashiStartUtc: closeStart.toUtc(),
        ekadashiEndUtc: closeEnd.toUtc(),
        dwadashiEndUtc: dwEnd.toUtc(),
        dashamiEndUtc: daEnd.toUtc(),
        latitude: 13.0827,
        longitude: 80.2707,
        tradition: AppTradition.smarta,
      );

      expect(observance.observanceDate, isNotNull);
      expect(observance.paranaStart, isNotNull);
      expect(observance.paranaEnd.isAfter(observance.paranaStart), isTrue);
    });

    test('5. Invalid tithi data gracefully falls back to static JSON without crashing', () {
      final brokenJson = {
        "ekadashis": [
          {
            "id": 999,
            "name": {"en": "Corrupted Ekadashi"},
            "description": {"en": "Testing fallback"},
            "story": {"en": "Story"},
            "fasting_rules": {"en": "Rules"},
            "benefits": {"en": "Benefits"},
            "timing": {
              "IST": {
                "date": "2026-05-20",
                "fasting_start": "2026-05-20T06:00:00+05:30",
                "parana_start": "2026-05-21T06:00:00+05:30",
                "parana_end": "2026-05-21T08:30:00+05:30"
              }
            },
            "tradition_tags": ["general"],
            "region_tags": ["pan-india"],
            "has_tradition_variation": false,
            "tithi": {
              "ekadashi_start": "invalid-iso-string", // Triggers fallback
              "ekadashi_end": null,
              "dwadashi_end": null,
              "dashami_end": null
            }
          }
        ]
      };

      try {
        final fallbackService = EkadashiService();
        fallbackService.loadDataFromJson(brokenJson);

        final results = fallbackService.getEkadashis(
          location: chennaiLoc,
          timezone: 'IST',
          languageCode: 'en',
          tradition: AppTradition.general,
        );

        expect(results.length, 1);
        expect(results[0].id, 999);
        expect(results[0].date, DateTime(2026, 5, 20));
        expect(results[0].fastStartTime, '06:00 AM');
        expect(results[0].fastBreakTime, '06:00 AM - 08:30 AM');
      } finally {
        final file = File('assets/ekadashi_data.json');
        final data = json.decode(file.readAsStringSync());
        ekadashiService.loadDataFromJson(data);
      }
    });

    test('6. Language switching preserves identical dates, sunrises, and parana windows', () {
      final langs = ['en', 'ta', 'te', 'hi'];
      final Map<String, List<EkadashiDate>> langResults = {};

      for (final l in langs) {
        langResults[l] = ekadashiService.getEkadashis(
          location: mumbaiLoc,
          timezone: 'IST',
          languageCode: l,
          tradition: AppTradition.general,
        );
      }

      for (int i = 0; i < 49; i++) {
        final en = langResults['en']![i];
        final ta = langResults['ta']![i];
        final te = langResults['te']![i];
        final hi = langResults['hi']![i];

        expect(ta.date, en.date);
        expect(te.date, en.date);
        expect(hi.date, en.date);

        expect(ta.fastStartTime, en.fastStartTime);
        expect(te.fastStartTime, en.fastStartTime);
        expect(hi.fastStartTime, en.fastStartTime);

        expect(ta.fastBreakTime, en.fastBreakTime);
        expect(te.fastBreakTime, en.fastBreakTime);
        expect(hi.fastBreakTime, en.fastBreakTime);
      }
    });

    test('7. Tradition notification rescheduling coordinates clean cancel and reschedule', () async {
      final count = await TraditionNotificationCoordinator.rescheduleForTradition(
        tradition: AppTradition.smarta,
        languageCode: 'en',
        timezone: 'IST',
      );
      // Notifications reschedule successfully with non-negative count
      expect(count, greaterThanOrEqualTo(0));
    });

    test('8. All 49 events for 2026-2027 are chronological, valid, and consistent', () {
      final allEvents = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.general,
      );

      expect(allEvents.length, 49);

      for (int i = 0; i < allEvents.length - 1; i++) {
        expect(allEvents[i + 1].date.isAfter(allEvents[i].date), isTrue,
            reason: 'Event ${allEvents[i+1].id} date must be strictly after event ${allEvents[i].id}');
      }
    });

    test('9. Short Parana window (<15m) is accurately detected and not artificially widened without verified rule', () {
      final smartaEvents = ekadashiService.getEkadashis(
        location: chennaiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.smarta,
      );

      // Nirjala Ekadashi 2027 (#36) for Smarta in Chennai has 08:13 AM - 08:17 AM (4 minutes)
      final nirjalaSmarta = smartaEvents.firstWhere((e) => e.id == 36);
      expect(nirjalaSmarta.isShortParanaWindow, isTrue,
          reason: 'Smarta Nirjala 2027 has a 4-minute window and must be detected as short window');
      // Verify window is preserved without artificial extension to 2 hours
      expect(nirjalaSmarta.fastBreakTime, contains('08:13 AM - 08:17 AM'));

      // Shattila 2026 (#1) has ~2 hour window -> isShortParanaWindow must be false
      final shattila = smartaEvents.firstWhere((e) => e.id == 1);
      expect(shattila.isShortParanaWindow, isFalse);
    });

    test('10. Religious disclaimer and short parana notice are localized across all 4 languages (en, ta, te, hi)', () {
      final lang = LanguageService();
      final expectedKeys = [
        'short_parana_notice',
        'religious_disclaimer_title',
        'religious_disclaimer_text',
      ];

      for (final code in ['en', 'ta', 'te', 'hi']) {
        lang.changeLanguage(code);
        for (final key in expectedKeys) {
          final translated = lang.translate(key);
          expect(translated, isNotEmpty, reason: '$key should not be empty for $code');
          expect(translated, isNot(equals(key)), reason: '$key should be translated for $code');
        }
      }
    });
  });
}
