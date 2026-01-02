import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class EkadashiDate {
  final String id;
  final String name;
  final DateTime date;
  final String fastStartTime;
  final String fastBreakTime;
  final String description;
  final String story;
  final String fastingRules;
  final String benefits;

  EkadashiDate({
    required this.id,
    required this.name,
    required this.date,
    required this.fastStartTime,
    required this.fastBreakTime,
    required this.description,
    this.story = '',
    this.fastingRules = '',
    this.benefits = '',
  });

  factory EkadashiDate.fromJson(Map<String, dynamic> json) {
    return EkadashiDate(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      date: DateTime.parse(json['date']),
      fastStartTime: json['fastStartTime'] ?? '',
      fastBreakTime: json['fastBreakTime'] ?? '',
      description: json['description'] ?? '',
      story: json['story'] ?? 'Story details coming soon...',
      fastingRules: json['fastingRules'] ?? 'Standard Ekadashi fasting rules apply.',
      benefits: json['benefits'] ?? 'Grants spiritual merit and purifies the heart.',
    );
  }
}

class EkadashiService {
  // Singleton pattern
  static final EkadashiService _instance = EkadashiService._internal();
  factory EkadashiService() => _instance;
  EkadashiService._internal();

  // Cache to hold data in memory: {'en': [List], 'hi': [List], 'ta': [List]}
  final Map<String, List<EkadashiDate>> _cache = {};
  bool _isDataLoaded = false;

  /// Loads ALL language files into memory on app startup.
  Future<void> initializeData() async {
    if (_isDataLoaded) return;

    try {
      // Load all 3 JSON files in parallel
      final results = await Future.wait([
        _loadJsonFile('assets/ekadashi_data_en.json'),
        _loadJsonFile('assets/ekadashi_data_hi.json'),
        _loadJsonFile('assets/ekadashi_data_ta.json'),
      ]);

      _cache['en'] = results[0];
      _cache['hi'] = results[1];
      _cache['ta'] = results[2];

      _isDataLoaded = true;
      debugPrint("Ekadashi Data Initialized Successfully");
    } catch (e) {
      debugPrint("Critical Error loading Ekadashi data: $e");
    }
  }

  Future<List<EkadashiDate>> _loadJsonFile(String path) async {
    try {
      final String response = await rootBundle.loadString(path);
      final List<dynamic> data = json.decode(response);
      return data.map((json) => EkadashiDate.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error loading $path: $e");
      return [];
    }
  }

  /// Returns data instantly from memory.
  List<EkadashiDate> getEkadashis(String languageCode) {
    if (!_isDataLoaded) {
      debugPrint("WARNING: Data not loaded yet. Returning empty list.");
      return [];
    }
    return _cache[languageCode] ?? _cache['en'] ?? [];
  }

  // Backward compatibility wrapper
  Future<List<EkadashiDate>> getUpcomingEkadashis({String languageCode = 'en'}) async {
    if (!_isDataLoaded) await initializeData();
    return getEkadashis(languageCode);
  }
}