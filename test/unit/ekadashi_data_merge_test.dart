import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

void main() {
  group('Merged 2026-2027 Ekadashi Data Tests', () {
    late Map<String, dynamic> data;
    late List<dynamic> ekadashis;
    final ekadashiService = EkadashiService();

    setUpAll(() {
      final file = File('assets/ekadashi_data.json');
      expect(file.existsSync(), isTrue, reason: 'assets/ekadashi_data.json must exist');
      final content = file.readAsStringSync();
      data = json.decode(content);
      ekadashis = data['ekadashis'];
    });

    test('date_range is updated to end at 2027-12-31', () {
      expect(data['date_range']['start'], '2026-01-01');
      expect(data['date_range']['end'], '2027-12-31');
    });

    test('Total event count is 49 (24 in 2026 and 25 in 2027)', () {
      expect(ekadashis.length, 49);

      final events2026 = ekadashis.where((e) {
        final d = e['timing']['IST']['date'] as String;
        return d.startsWith('2026-');
      }).toList();

      final events2027 = ekadashis.where((e) {
        final d = e['timing']['IST']['date'] as String;
        return d.startsWith('2027-');
      }).toList();

      expect(events2026.length, 24);
      expect(events2027.length, 25);
    });

    test('No duplicate event IDs exist and IDs are 1 to 49', () {
      final ids = ekadashis.map((e) => e['id'] as int).toList();
      final idSet = ids.toSet();

      expect(idSet.length, 49, reason: 'All 49 IDs must be unique');
      expect(ids, List.generate(49, (i) => i + 1));
    });

    test('No duplicate IST dates exist and dates are in chronological order', () {
      final dates = ekadashis.map((e) => e['timing']['IST']['date'] as String).toList();
      final dateSet = dates.toSet();

      expect(dateSet.length, 49, reason: 'All 49 IST dates must be unique');

      for (int i = 0; i < dates.length - 1; i++) {
        final current = DateTime.parse(dates[i]);
        final next = DateTime.parse(dates[i + 1]);
        expect(next.isAfter(current), isTrue,
            reason: 'Date ${dates[i + 1]} must be after ${dates[i]}');
      }
    });

    test('First 2027 event is Saphala (2027-01-03) and 25th 2027 event is Saphala (2027-12-23)', () {
      final first2027 = ekadashis[24];
      expect(first2027['id'], 25);
      expect(first2027['name']['en'], 'Saphala Ekadashi');
      expect(first2027['timing']['IST']['date'], '2027-01-03');

      final last2027 = ekadashis[48];
      expect(last2027['id'], 49);
      expect(last2027['name']['en'], 'Saphala Ekadashi');
      expect(last2027['timing']['IST']['date'], '2027-12-23');
    });

    test('All 2027 events have valid multilingual text (en, ta, hi, te)', () {
      for (int i = 24; i < 49; i++) {
        final e = ekadashis[i];
        final name = e['name'] as Map<String, dynamic>;
        final desc = e['description'] as Map<String, dynamic>;
        final rules = e['fasting_rules'] as Map<String, dynamic>;

        for (final lang in ['en', 'ta', 'hi', 'te']) {
          expect(name[lang]?.isNotEmpty, isTrue, reason: 'Missing name $lang for event ${e['id']}');
          expect(desc[lang]?.isNotEmpty, isTrue, reason: 'Missing desc $lang for event ${e['id']}');
          expect(rules[lang]?.isNotEmpty, isTrue, reason: 'Missing rules $lang for event ${e['id']}');
        }
      }
    });

    test('All 2027 events have valid ISO timestamps and parana window order', () {
      for (int i = 24; i < 49; i++) {
        final e = ekadashis[i];
        final ist = e['timing']['IST'] as Map<String, dynamic>;

        final fastStart = DateTime.parse(ist['fasting_start']);
        final paranaStart = DateTime.parse(ist['parana_start']);
        final paranaEnd = DateTime.parse(ist['parana_end']);

        expect(paranaStart.isAfter(fastStart), isTrue,
            reason: 'Parana start must be after fasting start for event ${e['id']}');
        expect(paranaEnd.isAfter(paranaStart), isTrue,
            reason: 'Parana end must be after parana start for event ${e['id']}');
      }
    });

    test('Verified 2027 tradition variations exist for Chennai (IDs 26, 36, 39, 42, 45)', () {
      final variationIds = [26, 36, 39, 42, 45];
      for (final id in variationIds) {
        final event = ekadashis.firstWhere((e) => e['id'] == id);
        expect(event['has_tradition_variation'], isTrue, reason: 'Event $id should have variation');

        final variants = event['tradition_variants'] as Map<String, dynamic>;
        expect(variants.containsKey('smarta'), isTrue, reason: 'Missing smarta for $id');
        expect(variants.containsKey('vaishnava'), isTrue, reason: 'Missing vaishnava for $id');

        final smartaDate = variants['smarta']['timing']['IST']['date'] as String;
        final vaishnavaDate = variants['vaishnava']['timing']['IST']['date'] as String;
        expect(smartaDate != vaishnavaDate, isTrue,
            reason: 'Event $id Smarta date ($smartaDate) should differ from Vaishnava date ($vaishnavaDate)');
      }
    });

    test('Switching traditions updates observance date, parana time, and rules in 2027', () {
      // Test Pausha Putrada Ekadashi (ID 26)
      final eventJson = ekadashis.firstWhere((e) => e['id'] == 26);
      final variantsJson = eventJson['tradition_variants'] as Map<String, dynamic>;

      final smartaVar = TraditionVariant(
        tradition: AppTradition.smarta,
        date: DateTime.parse(variantsJson['smarta']['timing']['IST']['date']),
        fastStartTime: '06:36 AM',
        fastBreakTime: '01:28 PM - 03:46 PM',
        fastingRules: variantsJson['smarta']['fasting_rules']['en'],
        source: variantsJson['smarta']['source'],
      );

      final vaishnavaVar = TraditionVariant(
        tradition: AppTradition.vaishnava,
        date: DateTime.parse(variantsJson['vaishnava']['timing']['IST']['date']),
        fastStartTime: '06:36 AM',
        fastBreakTime: '06:36 AM - 08:53 AM',
        fastingRules: variantsJson['vaishnava']['fasting_rules']['en'],
        source: variantsJson['vaishnava']['source'],
      );

      final ekadashiDate = EkadashiDate(
        id: 26,
        name: 'Pausha Putrada Ekadashi',
        date: DateTime(2027, 1, 18),
        fastStartTime: '06:36 AM',
        fastBreakTime: '01:28 PM - 03:46 PM',
        description: 'Grants worthy children.',
        traditionVariants: {
          AppTradition.smarta: smartaVar,
          AppTradition.vaishnava: vaishnavaVar,
        },
        hasTraditionVariation: true,
      );

      // 1. Smarta mode
      final smartaResolved = ekadashiService.resolveEkadashiObservance(
        event: ekadashiDate,
        userTradition: AppTradition.smarta,
      );
      expect(smartaResolved.primary.date, DateTime(2027, 1, 18));
      expect(smartaResolved.primary.fastBreakTime, '01:28 PM - 03:46 PM');
      expect(smartaResolved.alternate?.date, DateTime(2027, 1, 19));

      // 2. Vaishnava mode
      final vaishnavaResolved = ekadashiService.resolveEkadashiObservance(
        event: ekadashiDate,
        userTradition: AppTradition.vaishnava,
      );
      expect(vaishnavaResolved.primary.date, DateTime(2027, 1, 19));
      expect(vaishnavaResolved.primary.fastBreakTime, '06:36 AM - 08:53 AM');
      expect(vaishnavaResolved.alternate?.date, DateTime(2027, 1, 18));

      // 3. General mode
      final generalResolved = ekadashiService.resolveEkadashiObservance(
        event: ekadashiDate,
        userTradition: AppTradition.general,
      );
      expect(generalResolved.primary.date, DateTime(2027, 1, 18));
      expect(generalResolved.hasTraditionVariation, isTrue);
      expect(generalResolved.alternate, isNotNull);
    });
  });
}
