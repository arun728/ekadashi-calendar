import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/food_guide_models.dart';
import 'package:ekadashi_calendar/services/food_guide_service.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FoodGuide Dataset & Service Unit Tests', () {
    late String rawJsonString;
    late Map<String, dynamic> rawJson;
    late FoodGuideService service;

    setUpAll(() async {
      // Read the asset directly from file to verify dataset structure
      final file = File('assets/vrat_food_guide.json');
      expect(file.existsSync(), isTrue, reason: 'assets/vrat_food_guide.json must exist');
      rawJsonString = await file.readAsString();
      rawJson = json.decode(rawJsonString) as Map<String, dynamic>;

      service = FoodGuideService();
      // Load directly from json string
      service.loadFromJsonString(rawJsonString);
    });

    test('Dataset contains version, categories, and food_items', () {
      expect(rawJson['version'], isNotNull);
      expect(rawJson['categories'], isA<List>());
      expect(rawJson['food_items'], isA<List>());

      final categories = service.categories;
      expect(categories.length, greaterThanOrEqualTo(4));
      expect(categories.any((c) => c.id == 'pseudocereals_flours'), isTrue);
      expect(categories.any((c) => c.id == 'vegetables_roots'), isTrue);
      expect(categories.any((c) => c.id == 'dairy_fruits'), isTrue);
      expect(categories.any((c) => c.id == 'spices_seasonings'), isTrue);
    });

    test('All categories have English, Tamil, and Hindi translations', () {
      for (final cat in service.categories) {
        expect(cat.nameEn, isNotEmpty, reason: '${cat.id} missing English name');
        expect(cat.nameTa, isNotEmpty, reason: '${cat.id} missing Tamil name');
        expect(cat.nameHi, isNotEmpty, reason: '${cat.id} missing Hindi name');
        expect(cat.localizedName('en'), cat.nameEn);
        expect(cat.localizedName('ta'), cat.nameTa);
        expect(cat.localizedName('hi'), cat.nameHi);
      }
    });

    test('All food items have valid structure, statuses, and multi-lingual content', () {
      final items = service.allItems;
      expect(items.length, greaterThanOrEqualTo(20));

      for (final item in items) {
        expect(item.id, isNotEmpty);
        expect(item.category, isNotEmpty);
        expect(item.status, isNotNull);
        expect(
          [FoodFastStatus.allowed, FoodFastStatus.restricted, FoodFastStatus.optional],
          contains(item.status),
        );
        expect(item.traditionTags, isNotEmpty);

        // Check multi-language names
        final nameEn = item.localizedName('en');
        final nameTa = item.localizedName('ta');
        final nameHi = item.localizedName('hi');
        expect(nameEn, isNotEmpty, reason: 'Food ${item.id} missing English name');
        expect(nameTa, isNotEmpty, reason: 'Food ${item.id} missing Tamil name');
        expect(nameHi, isNotEmpty, reason: 'Food ${item.id} missing Hindi name');

        // Check multi-language explanations
        final expEn = item.localizedExplanation('en');
        final expTa = item.localizedExplanation('ta');
        final expHi = item.localizedExplanation('hi');
        expect(expEn, isNotEmpty, reason: 'Food ${item.id} missing English explanation');
        expect(expTa, isNotEmpty, reason: 'Food ${item.id} missing Tamil explanation');
        expect(expHi, isNotEmpty, reason: 'Food ${item.id} missing Hindi explanation');

        // Check alternative suggestions where available
        if (item.alternativeSuggestion != null) {
          expect(item.alternativeSuggestion, isNotEmpty);
        }
      }
    });

    test('Grain/pulse items are strictly restricted across all traditions', () {
      final grains = service.allItems.firstWhere((i) => i.id == 'cereal_grains');
      final pulses = service.allItems.firstWhere((i) => i.id == 'pulses_lentils');

      expect(grains.status, FoodFastStatus.restricted);
      expect(pulses.status, FoodFastStatus.restricted);

      expect(grains.appliesToTradition(AppTradition.general), isTrue);
      expect(grains.appliesToTradition(AppTradition.smarta), isTrue);
      expect(grains.appliesToTradition(AppTradition.vaishnava), isTrue);
    });

    test('Common allowed foods are allowed across all traditions', () {
      final sabudana = service.allItems.firstWhere((i) => i.id == 'sabudana');
      final sendhaNamak = service.allItems.firstWhere((i) => i.id == 'sendha_namak');
      final milk = service.allItems.firstWhere((i) => i.id == 'cow_milk_ghee');

      expect(sabudana.status, FoodFastStatus.allowed);
      expect(sendhaNamak.status, FoodFastStatus.allowed);
      expect(milk.status, FoodFastStatus.allowed);
    });

    test('Tradition divergence is explained neutrally without religious invention', () {
      // Mustard seeds: optional, avoided in Vaishnava, accepted in some Smarta practices
      final mustard = service.allItems.firstWhere((i) => i.id == 'mustard_seeds');
      expect(mustard.status, FoodFastStatus.optional);
      expect(mustard.hasAlternativePerspective(AppTradition.general), isTrue);
      expect(mustard.localizedExplanation('en'), contains('Vaishnava'));
      expect(mustard.localizedExplanation('ta'), isNotEmpty);
      expect(mustard.localizedExplanation('hi'), isNotEmpty);

      // Hing (commercial compounded asafoetida with wheat/rice flour)
      final hing = service.allItems.firstWhere((i) => i.id == 'asafoetida');
      expect(hing.status, FoodFastStatus.restricted);
      expect(hing.localizedExplanation('en'), contains('wheat'));
    });

    test('Filter by tradition (General, Smarta, Vaishnava)', () {
      final generalItems = service.filterItems(tradition: AppTradition.general);
      final smartaItems = service.filterItems(tradition: AppTradition.smarta);
      final vaishnavaItems = service.filterItems(tradition: AppTradition.vaishnava);

      expect(generalItems.isNotEmpty, isTrue);
      expect(smartaItems.isNotEmpty, isTrue);
      expect(vaishnavaItems.isNotEmpty, isTrue);

      // Mustard seeds apply to smarta and vaishnava, but not tagged as general
      expect(smartaItems.any((i) => i.id == 'mustard_seeds'), isTrue);
      expect(vaishnavaItems.any((i) => i.id == 'mustard_seeds'), isTrue);
      expect(generalItems.any((i) => i.id == 'mustard_seeds'), isFalse);
    });

    test('Filter by category ID', () {
      final flours = service.filterItems(
        tradition: AppTradition.general,
        categoryId: 'pseudocereals_flours',
      );
      expect(flours.every((i) => i.category == 'pseudocereals_flours'), isTrue);
      expect(flours.any((i) => i.id == 'kuttu'), isTrue);
      expect(flours.any((i) => i.id == 'sabudana'), isTrue);

      final spices = service.filterItems(
        tradition: AppTradition.general,
        categoryId: 'spices_seasonings',
      );
      expect(spices.every((i) => i.category == 'spices_seasonings'), isTrue);
      expect(spices.any((i) => i.id == 'sendha_namak'), isTrue);
    });

    test('Filter by status (allowed, restricted, optional)', () {
      final allowed = service.filterItems(
        tradition: AppTradition.general,
        status: FoodFastStatus.allowed,
      );
      expect(allowed.every((i) => i.status == FoodFastStatus.allowed), isTrue);

      final restricted = service.filterItems(
        tradition: AppTradition.general,
        status: FoodFastStatus.restricted,
      );
      expect(restricted.every((i) => i.status == FoodFastStatus.restricted), isTrue);

      final optional = service.filterItems(
        tradition: AppTradition.smarta,
        status: FoodFastStatus.optional,
      );
      expect(optional.every((i) => i.status == FoodFastStatus.optional), isTrue);
    });

    test('Search filter works across English, Tamil, and Hindi', () {
      // English search
      final searchEn = service.filterItems(
        tradition: AppTradition.general,
        searchQuery: 'Tapioca',
        languageCode: 'en',
      );
      expect(searchEn.any((i) => i.id == 'sabudana'), isTrue);

      // Hindi search
      final searchHi = service.filterItems(
        tradition: AppTradition.general,
        searchQuery: 'साबूदाना',
        languageCode: 'hi',
      );
      expect(searchHi.any((i) => i.id == 'sabudana'), isTrue);

      // Tamil search
      final searchTa = service.filterItems(
        tradition: AppTradition.general,
        searchQuery: 'ஜவ்வரிசி',
        languageCode: 'ta',
      );
      expect(searchTa.any((i) => i.id == 'sabudana'), isTrue);
    });
  });
}
