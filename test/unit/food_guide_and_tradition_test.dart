import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/food_guide_models.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';

void main() {
  group('Module 11 - VratFoodItem & Food Guide Filtering Tests', () {
    final foodItems = [
      const VratFoodItem(
        id: 'sabudana',
        name: 'Tapioca Pearls (Sabudana)',
        status: FoodFastStatus.allowed,
        traditionTags: ['general', 'smarta', 'vaishnava'],
        regionTags: ['pan-india', 'west-india', 'north-india'],
        explanation: 'Widely accepted satvik fasting food.',
      ),
      const VratFoodItem(
        id: 'sendha_namak',
        name: 'Rock Salt (Sendha Namak)',
        status: FoodFastStatus.allowed,
        traditionTags: ['general', 'smarta', 'vaishnava'],
        regionTags: ['pan-india'],
        explanation: 'Unprocessed salt permissible during vrat.',
      ),
      const VratFoodItem(
        id: 'mustard_seeds',
        name: 'Mustard Seeds (Rai)',
        status: FoodFastStatus.restricted,
        traditionTags: ['vaishnava'],
        regionTags: ['pan-india'],
        explanation: 'Avoided in orthodox Vaishnava traditions; allowed in some Smarta households.',
        alternativeSuggestion: 'Cumin seeds or ginger',
      ),
      const VratFoodItem(
        id: 'masoor_dal',
        name: 'Red Lentils (Masoor Dal)',
        status: FoodFastStatus.restricted,
        traditionTags: ['general', 'smarta', 'vaishnava'],
        regionTags: ['pan-india'],
        explanation: 'Grains and pulses are strictly prohibited on Ekadashi across all traditions.',
      ),
      const VratFoodItem(
        id: 'raw_banana',
        name: 'Raw Banana (Vazhaikkai)',
        status: FoodFastStatus.allowed,
        traditionTags: ['smarta'],
        regionTags: ['south-india'],
        explanation: 'Traditional south Indian vrat staple.',
      ),
    ];

    test('Food items correctly apply to general tradition', () {
      final generalItems = foodItems.where((item) => item.appliesToTradition(AppTradition.general)).toList();
      expect(generalItems.any((i) => i.id == 'sabudana'), isTrue);
      expect(generalItems.any((i) => i.id == 'sendha_namak'), isTrue);
      expect(generalItems.any((i) => i.id == 'masoor_dal'), isTrue);
      // Item tagged only for vaishnava does not apply to general
      expect(generalItems.any((i) => i.id == 'mustard_seeds'), isFalse);
    });

    test('Food items correctly filter by Vaishnava tradition', () {
      final vaishnavaItems = foodItems.where((item) => item.appliesToTradition(AppTradition.vaishnava)).toList();
      expect(vaishnavaItems.any((i) => i.id == 'mustard_seeds'), isTrue);
      expect(vaishnavaItems.any((i) => i.id == 'sabudana'), isTrue);
      // Item tagged only for general and smarta should not apply to vaishnava
      expect(vaishnavaItems.any((i) => i.id == 'raw_banana'), isFalse);
    });

    test('Food items correctly filter by region tags', () {
      final southIndiaItems = foodItems.where((item) => item.regionTags.contains('south-india') || item.regionTags.contains('pan-india')).toList();
      expect(southIndiaItems.any((i) => i.id == 'raw_banana'), isTrue);
      expect(southIndiaItems.any((i) => i.id == 'sabudana'), isTrue);
    });

    test('Alternative perspective detection', () {
      final mustard = foodItems.firstWhere((i) => i.id == 'mustard_seeds');
      expect(mustard.hasAlternativePerspective(AppTradition.smarta), isTrue);
      expect(mustard.hasAlternativePerspective(AppTradition.vaishnava), isFalse);
    });

    test('VratFoodItem JSON serialization and deserialization', () {
      final original = foodItems.firstWhere((i) => i.id == 'mustard_seeds');
      final jsonMap = original.toJson();
      final deserialized = VratFoodItem.fromJson(jsonMap);

      expect(deserialized.id, original.id);
      expect(deserialized.name, original.name);
      expect(deserialized.status, original.status);
      expect(deserialized.traditionTags, original.traditionTags);
      expect(deserialized.regionTags, original.regionTags);
      expect(deserialized.explanation, original.explanation);
      expect(deserialized.alternativeSuggestion, original.alternativeSuggestion);
    });
  });

  group('Module 11 - Religious Guidance & Non-Fabrication Verification', () {
    test('Non-divergent occurrences have no invented alternative dates', () {
      final service = EkadashiService();

      final standardEvent = EkadashiDate(
        id: 1,
        name: 'Shattila Ekadashi',
        date: DateTime(2026, 1, 14),
        fastStartTime: '06:35 AM',
        fastBreakTime: '06:35 AM - 08:52 AM',
        description: 'Sesame seeds significance',
        traditionVariants: const {},
        hasTraditionVariation: false,
      );

      final smartaObs = service.resolveEkadashiObservance(
        event: standardEvent,
        userTradition: AppTradition.smarta,
      );
      final vaishnavaObs = service.resolveEkadashiObservance(
        event: standardEvent,
        userTradition: AppTradition.vaishnava,
      );

      // Neither tradition invents a variant
      expect(smartaObs.hasTraditionVariation, isFalse);
      expect(smartaObs.alternate, isNull);
      expect(smartaObs.primary.date, standardEvent.date);

      expect(vaishnavaObs.hasTraditionVariation, isFalse);
      expect(vaishnavaObs.alternate, isNull);
      expect(vaishnavaObs.primary.date, standardEvent.date);
    });

    test('Divergent occurrences use exclusively vetted dates and rules', () {
      final service = EkadashiService();

      final smartaVariant = TraditionVariant(
        tradition: AppTradition.smarta,
        date: DateTime(2026, 11, 5),
        fastStartTime: '06:04 AM',
        fastBreakTime: '06:04 AM - 08:23 AM',
        fastingRules: 'Smarta fasting on Thursday',
        source: 'Drik Panchang Verified',
      );

      final vaishnavaVariant = TraditionVariant(
        tradition: AppTradition.vaishnava,
        date: DateTime(2026, 11, 6),
        fastStartTime: '06:05 AM',
        fastBreakTime: '06:05 AM - 08:24 AM',
        fastingRules: 'Vaishnava Rama Ekadashi on Friday',
        source: 'Vaishnava Calendar Verified',
      );

      final ramaEkadashi = EkadashiDate(
        id: 21,
        name: 'Rama Ekadashi',
        date: DateTime(2026, 11, 5),
        fastStartTime: '06:04 AM',
        fastBreakTime: '06:04 AM - 08:23 AM',
        description: 'Removes all sins',
        traditionVariants: {
          AppTradition.smarta: smartaVariant,
          AppTradition.vaishnava: vaishnavaVariant,
        },
        hasTraditionVariation: true,
      );

      final resolvedVaishnava = service.resolveEkadashiObservance(
        event: ramaEkadashi,
        userTradition: AppTradition.vaishnava,
      );

      expect(resolvedVaishnava.primary.date, DateTime(2026, 11, 6));
      expect(resolvedVaishnava.primary.fastingRules, 'Vaishnava Rama Ekadashi on Friday');
      expect(resolvedVaishnava.alternate!.date, DateTime(2026, 11, 5));
      expect(resolvedVaishnava.alternate!.fastingRules, 'Smarta fasting on Thursday');
    });
  });
}
