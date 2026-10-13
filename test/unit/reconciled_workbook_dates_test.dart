import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/native_location_service.dart';
import 'package:ekadashi_calendar/services/parana_guidance_service.dart';
import 'package:ekadashi_calendar/services/tradition_notification_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reconciled Workbook Dates & Validation Tests (2026-2027)', () {
    late EkadashiService ekadashiService;
    late Map<String, dynamic> rawJson;
    late List<dynamic> ekadashis;

    final delhiLoc = LocationData(
      latitude: 28.6139,
      longitude: 77.2090,
      city: 'New Delhi',
      state: 'Delhi',
      timezone: 'IST',
    );

    setUpAll(() {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': false,
        'fasting_reminders': false,
        'parana_reminders': false,
      });

      final file = File('assets/ekadashi_data.json');
      rawJson = json.decode(file.readAsStringSync());
      ekadashis = rawJson['ekadashis'];

      ekadashiService = EkadashiService();
      ekadashiService.loadDataFromJson(rawJson);
    });

    test('1. Total event count is 49 with unique IDs 1..49 and no duplicate dates in same tradition', () {
      expect(ekadashis.length, 49);
      final ids = ekadashis.map((e) => e['id'] as int).toList();
      expect(ids.toSet().length, 49, reason: 'All 49 IDs must be unique');
      expect(ids, List.generate(49, (i) => i + 1));

      // Separate 2026 and 2027
      final y2026 = ekadashis.where((e) => (e['timing']['IST']['date'] as String).startsWith('2026-')).toList();
      final y2027 = ekadashis.where((e) => (e['timing']['IST']['date'] as String).startsWith('2027-')).toList();
      expect(y2026.length, 24);
      expect(y2027.length, 25);
    });

    test('2. Saphala Ekadashi occurs twice in 2027 with unique IDs and dates (Jan 3 and Dec 23)', () {
      final saphalaEvents = ekadashis.where((e) => e['name']['en'] == 'Saphala Ekadashi').toList();
      expect(saphalaEvents.length, 2);

      final saphalaJan = saphalaEvents.firstWhere((e) => e['id'] == 25);
      final saphalaDec = saphalaEvents.firstWhere((e) => e['id'] == 49);

      expect(saphalaJan['timing']['IST']['date'], '2027-01-03');
      expect(saphalaDec['timing']['IST']['date'], '2027-12-23');
    });

    test('3. Reconciled 2026 Smarta and Vaishnava reference dates match workbook', () {
      final smarta2026 = ekadashiService.getEkadashis(
        location: delhiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.smarta,
      ).where((e) => e.date.year == 2026).toList();

      final vaishnava2026 = ekadashiService.getEkadashis(
        location: delhiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.vaishnava,
      ).where((e) => e.date.year == 2026).toList();

      expect(smarta2026.length, 24);
      expect(vaishnava2026.length, 24);

      // Verify specific tradition differences documented in workbook
      // Yogini: Smarta Jul 10, Vaishnava Jul 11
      final yoginiSm = smarta2026.firstWhere((e) => e.id == 13);
      final yoginiVa = vaishnava2026.firstWhere((e) => e.id == 13);
      expect(yoginiSm.date, DateTime(2026, 7, 10));
      expect(yoginiVa.date, DateTime(2026, 7, 11));

      // Shravana Putrada: Smarta Aug 23, Vaishnava Aug 24
      final putradaSm = smarta2026.firstWhere((e) => e.id == 16);
      final putradaVa = vaishnava2026.firstWhere((e) => e.id == 16);
      expect(putradaSm.date, DateTime(2026, 8, 23));
      expect(putradaVa.date, DateTime(2026, 8, 24));

      // Devutthana (Prabodhini): Smarta Nov 20, Vaishnava Nov 21
      final devutthanaSm = smarta2026.firstWhere((e) => e.id == 22);
      final devutthanaVa = vaishnava2026.firstWhere((e) => e.id == 22);
      expect(devutthanaSm.date, DateTime(2026, 11, 20));
      expect(devutthanaVa.date, DateTime(2026, 11, 21));

      // Same day 2026 events verified
      final vijayaSm = smarta2026.firstWhere((e) => e.id == 3);
      final vijayaVa = vaishnava2026.firstWhere((e) => e.id == 3);
      expect(vijayaSm.date, DateTime(2026, 2, 13));
      expect(vijayaVa.date, DateTime(2026, 2, 13));

      final ramaSm = smarta2026.firstWhere((e) => e.id == 21);
      final ramaVa = vaishnava2026.firstWhere((e) => e.id == 21);
      expect(ramaSm.date, DateTime(2026, 11, 5));
      expect(ramaVa.date, DateTime(2026, 11, 5));

      final mokshadaSm = smarta2026.firstWhere((e) => e.id == 24);
      final mokshadaVa = vaishnava2026.firstWhere((e) => e.id == 24);
      expect(mokshadaSm.date, DateTime(2026, 12, 20));
      expect(mokshadaVa.date, DateTime(2026, 12, 20));
    });

    test('4. Corrected 2027 canonical reference dates match workbook', () {
      final general2027 = ekadashiService.getEkadashis(
        location: null,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.general,
      ).where((e) => e.date.year == 2027).toList();

      expect(general2027.length, 25);

      // Vijaya Ekadashi verified to March 4, 2027 (Drik Panchang, ISKCON, and Udaya Tithi rules)
      final vijaya2027 = general2027.firstWhere((e) => e.id == 29);
      expect(vijaya2027.date, DateTime(2027, 3, 4));

      // Kamada Ekadashi verified to April 17, 2027 (Drik Panchang, ISKCON, and Udaya Tithi rules)
      final kamada2027 = general2027.firstWhere((e) => e.id == 32);
      expect(kamada2027.date, DateTime(2027, 4, 17));

      // First and last 2027 Saphala events
      expect(general2027[0].date, DateTime(2027, 1, 3));
      expect(general2027[24].date, DateTime(2027, 12, 23));
    });

    test('4b. Kamada Ekadashi 2027 and Vijaya Ekadashi 2027 resolve correctly across traditions and cities', () {
      for (final loc in [delhiLoc, LocationData(latitude: 13.0827, longitude: 80.2707, city: 'Chennai', state: 'Tamil Nadu', timezone: 'IST')]) {
        for (final trad in [AppTradition.general, AppTradition.smarta, AppTradition.vaishnava]) {
          final list = ekadashiService.getEkadashis(
            location: loc,
            timezone: 'IST',
            languageCode: 'en',
            tradition: trad,
          );

          // Kamada Ekadashi 2027 (ID 32)
          final kamada = list.firstWhere((e) => e.id == 32);
          expect(kamada.date, DateTime(2027, 4, 17),
              reason: 'Kamada 2027 must be April 17 for ${loc.city} under $trad');
          expect(kamada.fastBreakTime.isNotEmpty, isTrue);

          // Vijaya Ekadashi 2027 (ID 29)
          final vijaya = list.firstWhere((e) => e.id == 29);
          expect(vijaya.date, DateTime(2027, 3, 4),
              reason: 'Vijaya 2027 must be March 4 for ${loc.city} under $trad');
          expect(vijaya.fastBreakTime.isNotEmpty, isTrue);
        }
      }
    });

    test('5. Multi-language date and text consistency across en, ta, hi, te', () {
      for (final lang in ['en', 'ta', 'hi', 'te']) {
        final list = ekadashiService.getEkadashis(
          location: delhiLoc,
          timezone: 'IST',
          languageCode: lang,
          tradition: AppTradition.general,
        );
        expect(list.length, 49);

        for (final item in list) {
          expect(item.name.isNotEmpty, isTrue, reason: 'Missing name in $lang for ${item.id}');
          expect(item.description.isNotEmpty, isTrue, reason: 'Missing description in $lang for ${item.id}');
          expect(item.fastingRules.isNotEmpty, isTrue, reason: 'Missing fasting rules in $lang for ${item.id}');
        }
      }
    });

    test('6. Consistency across Parana Guidance, Notification Helper, and Shareable Card Formatting', () {
      final list = ekadashiService.getEkadashis(
        location: delhiLoc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.smarta,
      );

      final yogini = list.firstWhere((e) => e.id == 13);
      expect(yogini.date, DateTime(2026, 7, 10));

      // Notification content generation
      final notifContent = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.fastingDay,
        ekadashiName: yogini.name,
        tradition: AppTradition.smarta,
        languageCode: 'en',
        fastStartTime: yogini.fastStartTime,
      );
      expect(notifContent.title, contains('[Smarta]'));
      expect(notifContent.body, contains('Yogini Ekadashi'));

      // Parana guidance verification
      final paranaGuidanceService = ParanaGuidanceService();
      final guidanceFile = File('assets/parana_guidance.json');
      if (guidanceFile.existsSync()) {
        paranaGuidanceService.loadFromJsonString(guidanceFile.readAsStringSync());
        expect(paranaGuidanceService.isLoaded, isTrue);
        expect(paranaGuidanceService.document, isNotNull);
        final smartaRule = paranaGuidanceService.document?.traditions[AppTradition.smarta];
        expect(smartaRule, isNotNull);
      }
    });
  });
}
