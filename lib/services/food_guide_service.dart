import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'food_guide_models.dart';
import 'tradition_service.dart';

class VratFoodCategory {
  final String id;
  final String name;
  final Map<String, String>? names;

  const VratFoodCategory({
    required this.id,
    required this.name,
    this.names,
  });

  String get nameEn => names?['en'] ?? name;
  String get nameTa => names?['ta'] ?? name;
  String get nameHi => names?['hi'] ?? name;

  String localizedName(String langCode) {
    return names?[langCode] ?? names?['en'] ?? name;
  }
}

class FoodGuideService {
  static final FoodGuideService _instance = FoodGuideService._internal();
  factory FoodGuideService() => _instance;
  FoodGuideService._internal();

  bool _isLoaded = false;
  final List<VratFoodItem> _allItems = [];
  final List<VratFoodCategory> _categories = [];

  bool get isLoaded => _isLoaded;
  List<VratFoodItem> get allItems => List.unmodifiable(_allItems);
  List<VratFoodCategory> get categories => List.unmodifiable(_categories);

  /// Load and parse food guide from raw JSON string (useful for testing or direct loading)
  void loadFromJsonString(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;

    _categories.clear();
    final catList = data['categories'] as List<dynamic>? ?? [];
    for (var catJson in catList) {
      final catMap = catJson as Map<String, dynamic>;
      final namesMap = (catMap['name'] is Map)
          ? (catMap['name'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
          : null;
      final nameStr = namesMap?['en'] ?? catMap['name'] as String? ?? catMap['id'] as String;

      _categories.add(VratFoodCategory(
        id: catMap['id'] as String,
        name: nameStr,
        names: namesMap,
      ));
    }

    _allItems.clear();
    final itemList = data['food_items'] as List<dynamic>? ?? [];
    for (var itemJson in itemList) {
      _allItems.add(VratFoodItem.fromJson(itemJson as Map<String, dynamic>));
    }

    _isLoaded = true;
  }

  Future<void> initializeData() async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle.loadString('assets/vrat_food_guide.json');
      loadFromJsonString(jsonString);
      debugPrint("✅ Food Guide Data Loaded Successfully: ${_allItems.length} items");
    } catch (e) {
      debugPrint("❌ Error loading Food Guide data: $e");
      _isLoaded = true;
    }
  }

  /// Filter food items by tradition, category, status, and search query
  List<VratFoodItem> filterItems({
    AppTradition tradition = AppTradition.general,
    String? categoryId,
    FoodFastStatus? status,
    String? searchQuery,
    String languageCode = 'en',
  }) {
    return _allItems.where((item) {
      // Tradition filter:
      if (!item.appliesToTradition(tradition)) {
        return false;
      }

      // Category filter:
      if (categoryId != null && categoryId != 'all' && item.category != categoryId) {
        return false;
      }

      // Status filter:
      if (status != null && item.status != status) {
        return false;
      }

      // Search query filter:
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final name = item.localizedName(languageCode).toLowerCase();
        final enName = item.localizedName('en').toLowerCase();
        final explanation = item.localizedExplanation(languageCode).toLowerCase();
        final alt = (item.localizedAlternative(languageCode) ?? '').toLowerCase();

        final matches = name.contains(query) ||
            enName.contains(query) ||
            explanation.contains(query) ||
            alt.contains(query);

        if (!matches) return false;
      }

      return true;
    }).toList();
  }
}
