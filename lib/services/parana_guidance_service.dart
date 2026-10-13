import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'parana_guidance_models.dart';

class ParanaGuidanceService {
  static final ParanaGuidanceService _instance = ParanaGuidanceService._internal();
  factory ParanaGuidanceService() => _instance;
  ParanaGuidanceService._internal();

  bool _isLoaded = false;
  ParanaGuidanceDocument? _document;

  bool get isLoaded => _isLoaded;
  ParanaGuidanceDocument? get document => _document;

  /// Load and parse Parana guidance from raw JSON string (useful for testing and offline direct loading)
  void loadFromJsonString(String jsonString) {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      _document = ParanaGuidanceDocument.fromJson(data);
      _isLoaded = true;
    } catch (e) {
      debugPrint("❌ Error parsing Parana guidance json: $e");
    }
  }

  /// Initialize and load dataset from Flutter asset bundle
  Future<void> initializeData() async {
    if (_isLoaded && _document != null) return;

    try {
      final jsonString = await rootBundle.loadString('assets/parana_guidance.json');
      loadFromJsonString(jsonString);
      debugPrint("✅ Parana Guidance Data Loaded Successfully");
    } catch (e) {
      debugPrint("❌ Error loading Parana Guidance data from asset bundle: $e");
      // Fallback empty document so callers don't crash
      _isLoaded = true;
    }
  }
}
