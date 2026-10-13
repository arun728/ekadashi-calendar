import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported tradition preferences for Ekadashi observance.
enum AppTradition {
  general,
  smarta,
  vaishnava;

  String get id => name;

  static AppTradition fromId(String? id) {
    switch (id?.toLowerCase().trim()) {
      case 'smarta':
        return AppTradition.smarta;
      case 'vaishnava':
        return AppTradition.vaishnava;
      case 'general':
      default:
        return AppTradition.general;
    }
  }
}

/// Service managing user tradition preference.
/// Extends ChangeNotifier to allow reactive updates across screens without restart.
class TraditionService extends ChangeNotifier {
  static const String _prefKeyTradition = 'user_tradition';
  static const String _prefKeyOnboarded = 'tradition_onboarding_completed';

  /// Optional global listener/callback for notification rescheduling or external sync
  static Future<void> Function(AppTradition tradition)? onTraditionChanged;

  AppTradition _currentTradition = AppTradition.general;
  bool _isInitialized = false;

  AppTradition get currentTradition => _currentTradition;
  String get traditionId => _currentTradition.name;
  bool get isInitialized => _isInitialized;

  TraditionService() {
    loadTradition();
  }

  /// Load persisted tradition preference from SharedPreferences
  Future<void> loadTradition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKeyTradition);
      if (savedId != null) {
        _currentTradition = AppTradition.fromId(savedId);
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tradition preference: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Update user tradition preference and persist to disk
  Future<void> setTradition(AppTradition tradition) async {
    if (_currentTradition == tradition) return;
    _currentTradition = tradition;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyTradition, tradition.name);
      await prefs.setBool(_prefKeyOnboarded, true);
    } catch (e) {
      debugPrint('Error saving tradition preference: $e');
    }

    if (onTraditionChanged != null) {
      try {
        await onTraditionChanged!(_currentTradition);
      } catch (e) {
        debugPrint('Error in onTraditionChanged callback: $e');
      }
    }
  }

  /// Check if user has explicitly completed tradition onboarding
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyOnboarded) ?? prefs.containsKey(_prefKeyTradition);
  }

  /// Complete onboarding with selected tradition (defaults to general if skipped)
  Future<void> completeOnboarding(AppTradition tradition) async {
    _currentTradition = tradition;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyTradition, tradition.name);
    await prefs.setBool(_prefKeyOnboarded, true);

    if (onTraditionChanged != null) {
      try {
        await onTraditionChanged!(_currentTradition);
      } catch (e) {
        debugPrint('Error in onTraditionChanged callback: $e');
      }
    }
  }
}
