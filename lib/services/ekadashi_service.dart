import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Ekadashi date with timezone-aware timing
class EkadashiDate {
  final int id;
  final String name;
  final DateTime date;
  final String fastStartTime;
  final String fastBreakTime;
  final String description;
  final String story;
  final String fastingRules;
  final String benefits;
  final String paksha;
  final String month;

  // Full ISO datetime strings for notification scheduling
  final String fastingStartIso;
  final String paranaStartIso;
  final String paranaEndIso;

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
    this.paksha = '',
    this.month = '',
    this.fastingStartIso = '',
    this.paranaStartIso = '',
    this.paranaEndIso = '',
  });
}

/// City information for selection
class CityInfo {
  final String id;
  final String name;
  final String country;
  final String timezone;

  CityInfo({
    required this.id,
    required this.name,
    required this.country,
    required this.timezone,
  });
}

/// Main Ekadashi data service with multi-timezone support
class EkadashiService {
  static final EkadashiService _instance = EkadashiService._internal();
  factory EkadashiService() => _instance;
  EkadashiService._internal();

  // Raw data cache
  Map<String, dynamic>? _rawData;
  bool _isDataLoaded = false;

  // Parsed data cache by timezone and language
  final Map<String, Map<String, List<EkadashiDate>>> _cache = {};

  // Supported timezones
  static const List<String> supportedTimezones = ['IST', 'EST', 'CST', 'MST', 'PST'];

  // City list by timezone
  static final Map<String, List<CityInfo>> citiesByTimezone = {
    'IST': [
      CityInfo(id: 'chennai', name: 'Chennai', country: 'India', timezone: 'IST'),
      CityInfo(id: 'mumbai', name: 'Mumbai', country: 'India', timezone: 'IST'),
      CityInfo(id: 'delhi', name: 'Delhi', country: 'India', timezone: 'IST'),
      CityInfo(id: 'kolkata', name: 'Kolkata', country: 'India', timezone: 'IST'),
      CityInfo(id: 'bangalore', name: 'Bangalore', country: 'India', timezone: 'IST'),
      CityInfo(id: 'hyderabad', name: 'Hyderabad', country: 'India', timezone: 'IST'),
      CityInfo(id: 'pune', name: 'Pune', country: 'India', timezone: 'IST'),
      CityInfo(id: 'ahmedabad', name: 'Ahmedabad', country: 'India', timezone: 'IST'),
      CityInfo(id: 'jaipur', name: 'Jaipur', country: 'India', timezone: 'IST'),
      CityInfo(id: 'lucknow', name: 'Lucknow', country: 'India', timezone: 'IST'),
    ],
    'EST': [
      CityInfo(id: 'new_york', name: 'New York', country: 'United States', timezone: 'EST'),
      CityInfo(id: 'boston', name: 'Boston', country: 'United States', timezone: 'EST'),
      CityInfo(id: 'newark', name: 'Newark (NJ)', country: 'United States', timezone: 'EST'),
      CityInfo(id: 'philadelphia', name: 'Philadelphia', country: 'United States', timezone: 'EST'),
      CityInfo(id: 'atlanta', name: 'Atlanta', country: 'United States', timezone: 'EST'),
      CityInfo(id: 'miami', name: 'Miami', country: 'United States', timezone: 'EST'),
      CityInfo(id: 'washington_dc', name: 'Washington DC', country: 'United States', timezone: 'EST'),
    ],
    'CST': [
      CityInfo(id: 'chicago', name: 'Chicago', country: 'United States', timezone: 'CST'),
      CityInfo(id: 'houston', name: 'Houston', country: 'United States', timezone: 'CST'),
      CityInfo(id: 'dallas', name: 'Dallas', country: 'United States', timezone: 'CST'),
      CityInfo(id: 'san_antonio', name: 'San Antonio', country: 'United States', timezone: 'CST'),
      CityInfo(id: 'austin', name: 'Austin', country: 'United States', timezone: 'CST'),
    ],
    'MST': [
      CityInfo(id: 'denver', name: 'Denver', country: 'United States', timezone: 'MST'),
      CityInfo(id: 'phoenix', name: 'Phoenix', country: 'United States', timezone: 'MST'),
      CityInfo(id: 'albuquerque', name: 'Albuquerque', country: 'United States', timezone: 'MST'),
      CityInfo(id: 'salt_lake_city', name: 'Salt Lake City', country: 'United States', timezone: 'MST'),
    ],
    'PST': [
      CityInfo(id: 'los_angeles', name: 'Los Angeles', country: 'United States', timezone: 'PST'),
      CityInfo(id: 'san_francisco', name: 'San Francisco', country: 'United States', timezone: 'PST'),
      CityInfo(id: 'san_jose', name: 'San Jose', country: 'United States', timezone: 'PST'),
      CityInfo(id: 'seattle', name: 'Seattle', country: 'United States', timezone: 'PST'),
      CityInfo(id: 'portland', name: 'Portland', country: 'United States', timezone: 'PST'),
    ],
  };

  /// Initialize and load data from JSON
  Future<void> initializeData() async {
    if (_isDataLoaded) return;

    try {
      final String response = await rootBundle.loadString('assets/ekadashi_data.json');
      _rawData = json.decode(response);
      _isDataLoaded = true;
      debugPrint("✅ Ekadashi Data Initialized Successfully");
    } catch (e) {
      debugPrint("❌ Critical Error loading Ekadashi data: $e");
      // Fallback to empty data
      _rawData = {'ekadashis': []};
      _isDataLoaded = true;
    }
  }

  /// Get Ekadashi list for a specific timezone and language
  List<EkadashiDate> getEkadashis({
    required String timezone,
    required String languageCode,
  }) {
    if (!_isDataLoaded || _rawData == null) {
      debugPrint("WARNING: Data not loaded yet. Returning empty list.");
      return [];
    }

    // Check cache first
    final cacheKey = '${timezone}_$languageCode';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]![languageCode] ?? [];
    }

    // Parse data for this timezone/language combination
    final List<EkadashiDate> ekadashis = [];
    final ekadashiList = _rawData!['ekadashis'] as List<dynamic>? ?? [];

    for (var ekadashiJson in ekadashiList) {
      try {
        final timing = ekadashiJson['timing']?[timezone];
        if (timing == null) continue;

        final names = ekadashiJson['name'] as Map<String, dynamic>? ?? {};
        final descriptions = ekadashiJson['description'] as Map<String, dynamic>? ?? {};
        final stories = ekadashiJson['story'] as Map<String, dynamic>? ?? {};
        final rules = ekadashiJson['fasting_rules'] as Map<String, dynamic>? ?? {};
        final benefitsMap = ekadashiJson['benefits'] as Map<String, dynamic>? ?? {};

        // Parse datetime strings
        final fastingStartIso = timing['fasting_start'] as String? ?? '';
        final paranaStartIso = timing['parana_start'] as String? ?? '';
        final paranaEndIso = timing['parana_end'] as String? ?? '';

        // Parse date
        final dateStr = timing['date'] as String? ?? '';
        final date = DateTime.tryParse(dateStr) ?? DateTime.now();

        // Format display times
        final fastStartTime = _formatTimeFromIso(fastingStartIso);
        final fastBreakTime = _formatParanaWindow(paranaStartIso, paranaEndIso);

        ekadashis.add(EkadashiDate(
          id: ekadashiJson['id'] as int? ?? 0,
          name: names[languageCode] as String? ?? names['en'] as String? ?? '',
          date: date,
          fastStartTime: fastStartTime,
          fastBreakTime: fastBreakTime,
          description: descriptions[languageCode] as String? ?? descriptions['en'] as String? ?? '',
          story: stories[languageCode] as String? ?? stories['en'] as String? ?? 'Story coming soon...',
          fastingRules: rules[languageCode] as String? ?? rules['en'] as String? ?? 'Standard Ekadashi fasting rules apply.',
          benefits: benefitsMap[languageCode] as String? ?? benefitsMap['en'] as String? ?? 'Grants spiritual merit.',
          paksha: ekadashiJson['paksha'] as String? ?? '',
          month: ekadashiJson['month'] as String? ?? '',
          fastingStartIso: fastingStartIso,
          paranaStartIso: paranaStartIso,
          paranaEndIso: paranaEndIso,
        ));
      } catch (e) {
        debugPrint("Error parsing Ekadashi: $e");
      }
    }

    // Sort by date
    ekadashis.sort((a, b) => a.date.compareTo(b.date));

    // Cache the result
    _cache[cacheKey] = {languageCode: ekadashis};

    return ekadashis;
  }

  /// Format ISO datetime to display time (e.g., "06:40 AM")
  /// IMPORTANT: Extract time directly from ISO string WITHOUT timezone conversion.
  /// The JSON already has correct times for each timezone, so we display as-is.
  String _formatTimeFromIso(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      // Extract time directly from ISO string without timezone conversion
      // Format: "2026-01-14T06:40:00+05:30" -> extract "06:40"
      final tIndex = isoString.indexOf('T');
      if (tIndex == -1 || tIndex >= isoString.length - 1) return '';

      // Get the time part (after T, before timezone offset)
      String timePart = isoString.substring(tIndex + 1);
      // Remove timezone offset if present (+/-HH:MM or Z)
      final plusIndex = timePart.indexOf('+');
      final minusIndex = timePart.lastIndexOf('-');
      final zIndex = timePart.indexOf('Z');
      if (plusIndex > 0) {
        timePart = timePart.substring(0, plusIndex);
      } else if (minusIndex > 0) {
        timePart = timePart.substring(0, minusIndex);
      } else if (zIndex > 0) {
        timePart = timePart.substring(0, zIndex);
      }

      // Parse HH:MM:SS
      final parts = timePart.split(':');
      if (parts.length < 2) return '';

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      debugPrint('Error parsing time from ISO: $e');
      return '';
    }
  }

  /// Format parana window (e.g., "06:41 AM - 10:30 AM")
  String _formatParanaWindow(String startIso, String endIso) {
    final start = _formatTimeFromIso(startIso);
    final end = _formatTimeFromIso(endIso);
    if (start.isEmpty || end.isEmpty) return '';
    return '$start - $end';
  }

  /// Get all supported cities grouped by country
  Map<String, List<CityInfo>> getCitiesByCountry() {
    final Map<String, List<CityInfo>> result = {};

    for (var tzCities in citiesByTimezone.values) {
      for (var city in tzCities) {
        result.putIfAbsent(city.country, () => []);
        result[city.country]!.add(city);
      }
    }

    return result;
  }

  /// Get timezone for a city
  String getTimezoneForCity(String cityId) {
    for (var entry in citiesByTimezone.entries) {
      for (var city in entry.value) {
        if (city.id == cityId) {
          return entry.key;
        }
      }
    }
    return 'IST'; // Default
  }

  /// Get city info by ID
  CityInfo? getCityById(String cityId) {
    for (var tzCities in citiesByTimezone.values) {
      for (var city in tzCities) {
        if (city.id == cityId) {
          return city;
        }
      }
    }
    return null;
  }

  /// Backward compatibility - get Ekadashis with default IST timezone
  Future<List<EkadashiDate>> getUpcomingEkadashis({
    String languageCode = 'en',
    String timezone = 'IST',
  }) async {
    if (!_isDataLoaded) await initializeData();
    return getEkadashis(timezone: timezone, languageCode: languageCode);
  }

  /// Clear cache (useful when language changes)
  void clearCache() {
    _cache.clear();
  }

  /// Get the best matching app timezone based on device's system timezone.
  /// Used as fallback when location permission is denied.
  Future<String> getDeviceAppTimezone() async {
    try {
      final systemTimezone = await FlutterTimezone.getLocalTimezone();
      debugPrint('📍 Device system timezone: $systemTimezone');

      // Map common system timezone IDs to our supported app timezones
      const Map<String, String> timezoneMapping = {
        // IST - India Standard Time
        'Asia/Kolkata': 'IST',
        'Asia/Calcutta': 'IST',
        
        // EST - Eastern Standard Time
        'America/New_York': 'EST',
        'America/Detroit': 'EST',
        'America/Toronto': 'EST',
        'America/Indiana/Indianapolis': 'EST',
        'America/Kentucky/Louisville': 'EST',
        
        // CST - Central Standard Time
        'America/Chicago': 'CST',
        'America/Winnipeg': 'CST',
        'America/Mexico_City': 'CST',
        
        // MST - Mountain Standard Time
        'America/Denver': 'MST',
        'America/Edmonton': 'MST',
        'America/Phoenix': 'MST',
        'America/Boise': 'MST',
        
        // PST - Pacific Standard Time
        'America/Los_Angeles': 'PST',
        'America/Vancouver': 'PST',
        'America/Tijuana': 'PST',
      };

      // Direct lookup
      if (timezoneMapping.containsKey(systemTimezone)) {
        final appTimezone = timezoneMapping[systemTimezone]!;
        debugPrint('📍 Matched timezone: $systemTimezone → $appTimezone');
        return appTimezone;
      }

      // Fallback: Check by prefix for broader US timezone matching
      if (systemTimezone.startsWith('America/')) {
        // Try to infer from common patterns
        if (systemTimezone.contains('New_York') || 
            systemTimezone.contains('Detroit') ||
            systemTimezone.contains('Toronto') ||
            systemTimezone.contains('Indiana') ||
            systemTimezone.contains('Kentucky')) {
          debugPrint('📍 Inferred EST from: $systemTimezone');
          return 'EST';
        }
        if (systemTimezone.contains('Chicago') ||
            systemTimezone.contains('Winnipeg') ||
            systemTimezone.contains('Mexico')) {
          debugPrint('📍 Inferred CST from: $systemTimezone');
          return 'CST';
        }
        if (systemTimezone.contains('Denver') ||
            systemTimezone.contains('Phoenix') ||
            systemTimezone.contains('Edmonton') ||
            systemTimezone.contains('Boise')) {
          debugPrint('📍 Inferred MST from: $systemTimezone');
          return 'MST';
        }
        if (systemTimezone.contains('Los_Angeles') ||
            systemTimezone.contains('Vancouver') ||
            systemTimezone.contains('Seattle') ||
            systemTimezone.contains('Portland')) {
          debugPrint('📍 Inferred PST from: $systemTimezone');
          return 'PST';
        }
      }

      // India timezone fallback
      if (systemTimezone.startsWith('Asia/')) {
        debugPrint('📍 Default to IST for Asia timezone: $systemTimezone');
        return 'IST';
      }

      // Final fallback
      debugPrint('📍 No match found, defaulting to IST');
      return 'IST';
    } catch (e) {
      debugPrint('⚠️ Error getting device timezone: $e');
      return 'IST';
    }
  }
}