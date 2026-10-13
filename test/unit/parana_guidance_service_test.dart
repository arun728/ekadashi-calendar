import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/parana_guidance_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module 11 - Area 5: Parana Guidance Dataset & Service Unit Tests', () {
    late String rawJsonString;
    late Map<String, dynamic> rawJson;
    late ParanaGuidanceService service;

    setUpAll(() async {
      final file = File('assets/parana_guidance.json');
      expect(file.existsSync(), isTrue, reason: 'assets/parana_guidance.json must exist');
      rawJsonString = await file.readAsString();
      rawJson = json.decode(rawJsonString) as Map<String, dynamic>;

      service = ParanaGuidanceService();
      service.loadFromJsonString(rawJsonString);
    });

    test('Dataset contains version, canonical source, and verification notes', () {
      expect(rawJson['version'], isNotNull);
      expect(rawJson['source'], contains('Haribhaktivilasa'));
      expect(rawJson['source'], contains('Nirnaya Sindhu'));
      expect(rawJson['verification_status'], 'source_verified');

      final doc = service.document;
      expect(doc, isNotNull);
      expect(doc!.verificationNote, isNotEmpty);
      expect(doc.verificationNote, contains('astronomical'));
    });

    test('General guidance contains meaning, when_to_break, window_guidance, dwadashi_observance, and missed_window', () {
      final doc = service.document!;
      final general = doc.general;

      for (final lang in ['en', 'ta', 'hi', 'te']) {
        expect(general.localizedMeaning(lang), isNotEmpty, reason: 'Missing meaning for $lang');
        expect(general.localizedWhenToBreak(lang), isNotEmpty, reason: 'Missing whenToBreak for $lang');
        expect(general.localizedWindowGuidance(lang), isNotEmpty, reason: 'Missing windowGuidance for $lang');
        expect(general.localizedDwadashiObservance(lang), isNotEmpty, reason: 'Missing dwadashiObservance for $lang');
        expect(general.localizedMissedWindowGuidance(lang), isNotEmpty, reason: 'Missing missedWindowGuidance for $lang');
      }

      // Check key theological concepts in English
      expect(general.localizedWhenToBreak('en'), contains('Hari Vasara'));
      expect(general.localizedWhenToBreak('en'), contains('Dwadashi'));
      expect(general.localizedMissedWindowGuidance('en'), contains('Charanamrita'));
      expect(general.localizedMissedWindowGuidance('en'), contains('Tulasi'));
    });

    test('Tradition rules cover General, Smarta, and Vaishnava with canonical sources', () {
      final doc = service.document!;

      // General
      final generalRule = doc.traditions[AppTradition.general];
      expect(generalRule, isNotNull);
      expect(generalRule!.localizedTitle('en'), contains('General'));
      expect(generalRule.localizedRules('en'), isNotEmpty);

      // Smarta
      final smartaRule = doc.traditions[AppTradition.smarta];
      expect(smartaRule, isNotNull);
      expect(smartaRule!.source, contains('Dharma Sindhu'));
      expect(smartaRule.localizedRules('en'), contains('sunrise'));

      // Vaishnava
      final vaishnavaRule = doc.traditions[AppTradition.vaishnava];
      expect(vaishnavaRule, isNotNull);
      expect(vaishnavaRule!.source, contains('Haribhaktivilasa'));
      expect(vaishnavaRule.localizedRules('en'), contains('Hari Vasara'));
    });

    test('Tradition differences are neutrally presented across languages', () {
      final doc = service.document!;

      for (final lang in ['en', 'ta', 'hi', 'te']) {
        final diff = doc.localizedTraditionDifferences(lang);
        expect(diff, isNotEmpty, reason: 'Missing tradition differences note for $lang');
      }

      expect(doc.localizedTraditionDifferences('en'), contains('Smarta'));
      expect(doc.localizedTraditionDifferences('en'), contains('Vaishnava'));
    });

    test('Handles malformed or missing json gracefully without crashing', () {
      final testService = ParanaGuidanceService();
      // Should not throw on empty/corrupt json
      testService.loadFromJsonString('{}');
      expect(testService.isLoaded, isTrue);
      expect(testService.document, isNotNull);
      expect(testService.document!.general.localizedMeaning('en'), isEmpty);
    });

    test('Existing 2026-2027 Ekadashi event dates and Parana timestamps remain intact', () async {
      final ekadashiFile = File('assets/ekadashi_data.json');
      expect(ekadashiFile.existsSync(), isTrue);

      final ekadashiJson = json.decode(await ekadashiFile.readAsString()) as Map<String, dynamic>;
      final events = ekadashiJson['ekadashis'] as List<dynamic>;

      expect(events.length, 49); // 24 for 2026 + 25 for 2027

      for (final event in events) {
        final timing = event['timing'] as Map<String, dynamic>;
        expect(timing.containsKey('IST'), isTrue);

        final ist = timing['IST'] as Map<String, dynamic>;
        expect(ist['date'], isNotNull);
        expect(ist['parana_start'], isNotNull);
        expect(ist['parana_end'], isNotNull);
      }
    });
  });
}
