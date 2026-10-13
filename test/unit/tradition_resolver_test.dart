import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/native_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Tradition Resolver Logic Tests (Phase 20)', () {
    final ekadashiService = EkadashiService();

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
      description: 'Victory Ekadashi',
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
      description: 'Sesame seeds day',
      traditionVariants: const {},
      hasTraditionVariation: false,
    );

    test('Ekadashi with NO variation hides alternate date affordance', () {
      final resolved = ekadashiService.resolveEkadashiObservance(
        event: ekadashiWithoutVariation,
        userTradition: AppTradition.smarta,
      );

      expect(resolved.hasTraditionVariation, isFalse);
      expect(resolved.alternate, isNull);
      expect(resolved.primary.date, DateTime(2026, 1, 14));
    });

    test('Smarta user receives vetted Smarta observance date & timings', () {
      final resolved = ekadashiService.resolveEkadashiObservance(
        event: ekadashiWithVariation,
        userTradition: AppTradition.smarta,
      );

      expect(resolved.hasTraditionVariation, isTrue);
      expect(resolved.primary.date, DateTime(2026, 2, 13));
      expect(resolved.primary.fastStartTime, '06:32 AM');
      expect(resolved.primary.fastingRules, 'Smarta standard fasting rules');

      // Alternate should provide Vaishnava info
      expect(resolved.alternate, isNotNull);
      expect(resolved.alternate!.tradition, AppTradition.vaishnava);
      expect(resolved.alternate!.date, DateTime(2026, 2, 14));
      expect(resolved.alternate!.fastBreakTime, '06:31 AM - 10:15 AM');
    });

    test('Vaishnava user receives vetted Vaishnava observance date & timings', () {
      final resolved = ekadashiService.resolveEkadashiObservance(
        event: ekadashiWithVariation,
        userTradition: AppTradition.vaishnava,
      );

      expect(resolved.hasTraditionVariation, isTrue);
      expect(resolved.primary.date, DateTime(2026, 2, 14));
      expect(resolved.primary.fastStartTime, '06:31 AM');
      expect(resolved.primary.fastingRules, 'Vaishnava Dvadashi fasting rules');

      // Alternate should provide Smarta info
      expect(resolved.alternate, isNotNull);
      expect(resolved.alternate!.tradition, AppTradition.smarta);
      expect(resolved.alternate!.date, DateTime(2026, 2, 13));
      expect(resolved.alternate!.fastBreakTime, '06:32 AM - 08:52 AM');
    });

    test('General mode displays broadly applicable date with variation note', () {
      final resolved = ekadashiService.resolveEkadashiObservance(
        event: ekadashiWithVariation,
        userTradition: AppTradition.general,
      );

      expect(resolved.hasTraditionVariation, isTrue);
      expect(resolved.primary.date, DateTime(2026, 2, 13));
      expect(resolved.variationNote, 'Observance may vary by tradition or region.');
      expect(resolved.alternate, isNotNull);
    });

    test('No invented dates: resolver strictly returns dates from vetted input', () {
      final resolved = ekadashiService.resolveEkadashiObservance(
        event: ekadashiWithVariation,
        userTradition: AppTradition.vaishnava,
      );

      // Verifies exact date matches the vetted variant date without algorithmic math
      expect(resolved.primary.date, vaishnavaVariant.date);
    });

    test('Calculated tradition variation correctly populates variants and resolver returns alternate', () async {
      await ekadashiService.initializeData();
      final loc = LocationData(
        latitude: 13.04,
        longitude: 80.03,
        city: 'Palanjur',
        state: 'Tamil Nadu',
        timezone: 'IST',
      );

      final eventsSmarta = ekadashiService.getEkadashis(
        location: loc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.smarta,
      );

      final utpannaSmarta = eventsSmarta.firstWhere((e) => e.id == 23);
      expect(utpannaSmarta.hasTraditionVariation, isTrue);
      expect(utpannaSmarta.traditionVariants.containsKey(AppTradition.smarta), isTrue);
      expect(utpannaSmarta.traditionVariants.containsKey(AppTradition.vaishnava), isTrue);

      final resolvedSmarta = ekadashiService.resolveEkadashiObservance(
        event: utpannaSmarta,
        userTradition: AppTradition.smarta,
      );
      expect(resolvedSmarta.alternate, isNotNull);
      expect(resolvedSmarta.alternate!.tradition, AppTradition.vaishnava);
      expect(resolvedSmarta.alternate!.date, DateTime(2026, 12, 5));
      expect(resolvedSmarta.primary.date, DateTime(2026, 12, 4));

      final eventsVaishnava = ekadashiService.getEkadashis(
        location: loc,
        timezone: 'IST',
        languageCode: 'en',
        tradition: AppTradition.vaishnava,
      );

      final utpannaVaishnava = eventsVaishnava.firstWhere((e) => e.id == 23);
      final resolvedVaishnava = ekadashiService.resolveEkadashiObservance(
        event: utpannaVaishnava,
        userTradition: AppTradition.vaishnava,
      );
      expect(resolvedVaishnava.alternate, isNotNull);
      expect(resolvedVaishnava.alternate!.tradition, AppTradition.smarta);
      expect(resolvedVaishnava.alternate!.date, DateTime(2026, 12, 4));
      expect(resolvedVaishnava.primary.date, DateTime(2026, 12, 5));
    });
  });
}
