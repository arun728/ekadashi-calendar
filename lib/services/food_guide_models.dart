import 'tradition_service.dart';

/// Status of a food item during Ekadashi fasting
enum FoodFastStatus {
  allowed,     // Satvik non-grain foods permitted across traditions
  restricted,  // Grains, beans, onions, garlic, etc. strictly avoided
  optional,    // Permitted in some traditions or regions with conditions
}

/// A food guide item tagged by tradition and region with multi-language support
class VratFoodItem {
  final String id;
  final String name;
  final FoodFastStatus status;
  final List<String> traditionTags; // e.g. ['general', 'smarta', 'vaishnava']
  final List<String> regionTags;    // e.g. ['pan-india', 'south-india', 'north-india']
  final String explanation;
  final String? alternativeSuggestion;
  final String category;
  final Map<String, String>? names;
  final Map<String, String>? explanations;
  final Map<String, String>? alternativeSuggestions;

  const VratFoodItem({
    required this.id,
    required this.name,
    required this.status,
    required this.traditionTags,
    required this.regionTags,
    required this.explanation,
    this.alternativeSuggestion,
    this.category = 'general',
    this.names,
    this.explanations,
    this.alternativeSuggestions,
  });

  /// Get localized food name for given language code (en, ta, hi)
  String localizedName(String langCode) {
    if (names != null && names!.containsKey(langCode)) {
      return names![langCode]!;
    }
    return names?['en'] ?? name;
  }

  /// Get localized explanation for given language code (en, ta, hi)
  String localizedExplanation(String langCode) {
    if (explanations != null && explanations!.containsKey(langCode)) {
      return explanations![langCode]!;
    }
    return explanations?['en'] ?? explanation;
  }

  /// Get localized alternative suggestion for given language code (en, ta, hi)
  String? localizedAlternative(String langCode) {
    if (alternativeSuggestions != null && alternativeSuggestions!.containsKey(langCode)) {
      return alternativeSuggestions![langCode];
    }
    return alternativeSuggestions?['en'] ?? alternativeSuggestion;
  }

  /// Check whether this food item has specific guidance for a given tradition
  bool appliesToTradition(AppTradition tradition) {
    if (traditionTags.contains('general') || traditionTags.contains('all')) {
      return true;
    }
    return traditionTags.contains(tradition.name);
  }

  /// Check whether alternative tradition perspectives exist for this item
  bool hasAlternativePerspective(AppTradition currentTradition) {
    return traditionTags.any((t) => t != currentTradition.name && t != 'general');
  }

  factory VratFoodItem.fromJson(Map<String, dynamic> json, {String languageCode = 'en'}) {
    Map<String, String>? namesMap;
    String nameStr = '';
    if (json['name'] is Map) {
      namesMap = (json['name'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      nameStr = namesMap[languageCode] ?? namesMap['en'] ?? '';
    } else {
      nameStr = json['name'] as String? ?? '';
    }

    Map<String, String>? explMap;
    String explStr = '';
    if (json['explanation'] is Map) {
      explMap = (json['explanation'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      explStr = explMap[languageCode] ?? explMap['en'] ?? '';
    } else {
      explStr = json['explanation'] as String? ?? '';
    }

    Map<String, String>? altMap;
    String? altStr;
    if (json['alternativeSuggestion'] is Map) {
      altMap = (json['alternativeSuggestion'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      altStr = altMap[languageCode] ?? altMap['en'];
    } else {
      altStr = json['alternativeSuggestion'] as String?;
    }

    return VratFoodItem(
      id: json['id'] as String? ?? '',
      name: nameStr,
      status: FoodFastStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FoodFastStatus.allowed,
      ),
      traditionTags: (json['traditionTags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['general'],
      regionTags: (json['regionTags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['pan-india'],
      explanation: explStr,
      alternativeSuggestion: altStr,
      category: json['category'] as String? ?? 'general',
      names: namesMap,
      explanations: explMap,
      alternativeSuggestions: altMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': names ?? name,
      'status': status.name,
      'traditionTags': traditionTags,
      'regionTags': regionTags,
      'explanation': explanations ?? explanation,
      if (alternativeSuggestion != null || alternativeSuggestions != null)
        'alternativeSuggestion': alternativeSuggestions ?? alternativeSuggestion,
      if (category != 'general') 'category': category,
    };
  }
}
