import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'tradition_service.dart';
import 'panchang_calculator.dart';
import 'indian_cities_data.dart';
import 'native_location_service.dart';

/// Tradition-specific variant for an Ekadashi observance.
/// Sourced strictly from vetted calendar content (no runtime formula guessing).
class TraditionVariant {
  final AppTradition tradition;
  final DateTime date;
  final String fastStartTime;
  final String fastBreakTime;
  final String fastingStartIso;
  final String paranaStartIso;
  final String paranaEndIso;
  final String fastingRules;
  final String source;

  TraditionVariant({
    required this.tradition,
    required this.date,
    required this.fastStartTime,
    required this.fastBreakTime,
    this.fastingStartIso = '',
    this.paranaStartIso = '',
    this.paranaEndIso = '',
    this.fastingRules = '',
    this.source = 'vetted',
  });
}

/// Centralized result of resolving an Ekadashi for a user's tradition.
class ResolvedEkadashiObservance {
  final EkadashiDate primary;
  final TraditionVariant? alternate;
  final bool hasTraditionVariation;
  final AppTradition activeTradition;
  final String? variationNote;
  final String sourceStatus;

  ResolvedEkadashiObservance({
    required this.primary,
    this.alternate,
    required this.hasTraditionVariation,
    required this.activeTradition,
    this.variationNote,
    this.sourceStatus = 'verified',
  });
}

/// Ekadashi date with timezone-aware timing and tradition variation support
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

  // Module 11: Tradition tags and vetted variants
  final Map<AppTradition, TraditionVariant> traditionVariants;
  final List<String> traditionTags;
  final List<String> regionTags;
  final bool hasTraditionVariation;

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
    this.traditionVariants = const {},
    this.traditionTags = const ['general', 'smarta', 'vaishnava'],
    this.regionTags = const ['pan-india'],
    this.hasTraditionVariation = false,
  });

  /// Whether the Parana (fast-breaking) window is unusually short (less than 15 minutes).
  bool get isShortParanaWindow {
    if (paranaStartIso.isNotEmpty && paranaEndIso.isNotEmpty) {
      final start = DateTime.tryParse(paranaStartIso);
      final end = DateTime.tryParse(paranaEndIso);
      if (start != null && end != null && end.isAfter(start)) {
        return end.difference(start).inMinutes < 15;
      }
    }
    if (fastBreakTime.contains('-')) {
      final parts = fastBreakTime.split('-');
      if (parts.length == 2) {
        try {
          final t1 = parts[0].trim();
          final t2 = parts[1].trim();
          final f = DateFormat('hh:mm a');
          final dt1 = f.parse(t1);
          final dt2 = f.parse(t2);
          final diff = dt2.difference(dt1).inMinutes;
          return diff > 0 && diff < 15;
        } catch (_) {}
      }
    }
    return false;
  }

  EkadashiDate copyWith({
    int? id,
    String? name,
    DateTime? date,
    String? fastStartTime,
    String? fastBreakTime,
    String? description,
    String? story,
    String? fastingRules,
    String? benefits,
    String? paksha,
    String? month,
    String? fastingStartIso,
    String? paranaStartIso,
    String? paranaEndIso,
    Map<AppTradition, TraditionVariant>? traditionVariants,
    List<String>? traditionTags,
    List<String>? regionTags,
    bool? hasTraditionVariation,
  }) {
    return EkadashiDate(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      fastStartTime: fastStartTime ?? this.fastStartTime,
      fastBreakTime: fastBreakTime ?? this.fastBreakTime,
      description: description ?? this.description,
      story: story ?? this.story,
      fastingRules: fastingRules ?? this.fastingRules,
      benefits: benefits ?? this.benefits,
      paksha: paksha ?? this.paksha,
      month: month ?? this.month,
      fastingStartIso: fastingStartIso ?? this.fastingStartIso,
      paranaStartIso: paranaStartIso ?? this.paranaStartIso,
      paranaEndIso: paranaEndIso ?? this.paranaEndIso,
      traditionVariants: traditionVariants ?? this.traditionVariants,
      traditionTags: traditionTags ?? this.traditionTags,
      regionTags: regionTags ?? this.regionTags,
      hasTraditionVariation: hasTraditionVariation ?? this.hasTraditionVariation,
    );
  }
}

/// City information for selection
class CityInfo {
  final String id;
  final String name;
  final String country;
  final String timezone;
  final String state;
  final double latitude;
  final double longitude;

  CityInfo({
    required this.id,
    required this.name,
    required this.country,
    required this.timezone,
    this.state = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
  });
}

/// Main Ekadashi data service with multi-timezone and tradition support
class EkadashiService {
  static final EkadashiService _instance = EkadashiService._internal();
  factory EkadashiService() => _instance;
  EkadashiService._internal();

  // Raw data cache
  Map<String, dynamic>? _rawData;
  bool _isDataLoaded = false;

  // Parsed data cache by timezone, language, and tradition
  final Map<String, List<EkadashiDate>> _cache = {};

  // Supported timezones
  static const List<String> supportedTimezones = ['IST', 'EST', 'CST', 'MST', 'PST'];

  // Indian Cities Accessors
  List<IndianCity> get allIndianCities => IndianCitiesData.cities;
  List<String> get allIndianStates => IndianCitiesData.getAllStates();
  List<IndianCity> getCitiesForState(String state) => IndianCitiesData.getCitiesForState(state);

  // City list by timezone
  static final Map<String, List<CityInfo>> citiesByTimezone = {
    'IST': IndianCitiesData.cities.map((c) => CityInfo(
      id: c.id,
      name: '${c.name} (${c.state})',
      country: 'India',
      timezone: 'IST',
      state: c.state,
      latitude: c.latitude,
      longitude: c.longitude,
    )).toList(),
    'EST': [
      CityInfo(id: 'new_york', name: 'New York', country: 'United States', timezone: 'EST', latitude: 40.7128, longitude: -74.0060),
      CityInfo(id: 'boston', name: 'Boston', country: 'United States', timezone: 'EST', latitude: 42.3601, longitude: -71.0589),
      CityInfo(id: 'newark', name: 'Newark (NJ)', country: 'United States', timezone: 'EST', latitude: 40.7357, longitude: -74.1724),
      CityInfo(id: 'philadelphia', name: 'Philadelphia', country: 'United States', timezone: 'EST', latitude: 39.9526, longitude: -75.1652),
      CityInfo(id: 'atlanta', name: 'Atlanta', country: 'United States', timezone: 'EST', latitude: 33.7490, longitude: -84.3880),
      CityInfo(id: 'miami', name: 'Miami', country: 'United States', timezone: 'EST', latitude: 25.7617, longitude: -80.1918),
      CityInfo(id: 'washington_dc', name: 'Washington DC', country: 'United States', timezone: 'EST', latitude: 38.9072, longitude: -77.0369),
    ],
    'CST': [
      CityInfo(id: 'chicago', name: 'Chicago', country: 'United States', timezone: 'CST', latitude: 41.8781, longitude: -87.6298),
      CityInfo(id: 'houston', name: 'Houston', country: 'United States', timezone: 'CST', latitude: 29.7604, longitude: -95.3698),
      CityInfo(id: 'dallas', name: 'Dallas', country: 'United States', timezone: 'CST', latitude: 32.7767, longitude: -96.7970),
      CityInfo(id: 'san_antonio', name: 'San Antonio', country: 'United States', timezone: 'CST', latitude: 29.4241, longitude: -98.4936),
      CityInfo(id: 'austin', name: 'Austin', country: 'United States', timezone: 'CST', latitude: 30.2672, longitude: -97.7431),
    ],
    'MST': [
      CityInfo(id: 'denver', name: 'Denver', country: 'United States', timezone: 'MST', latitude: 39.7392, longitude: -104.9903),
      CityInfo(id: 'phoenix', name: 'Phoenix', country: 'United States', timezone: 'MST', latitude: 33.4484, longitude: -112.0740),
      CityInfo(id: 'albuquerque', name: 'Albuquerque', country: 'United States', timezone: 'MST', latitude: 35.0844, longitude: -106.6504),
      CityInfo(id: 'salt_lake_city', name: 'Salt Lake City', country: 'United States', timezone: 'MST', latitude: 40.7608, longitude: -111.8910),
    ],
    'PST': [
      CityInfo(id: 'los_angeles', name: 'Los Angeles', country: 'United States', timezone: 'PST', latitude: 34.0522, longitude: -118.2437),
      CityInfo(id: 'san_francisco', name: 'San Francisco', country: 'United States', timezone: 'PST', latitude: 37.7749, longitude: -122.4194),
      CityInfo(id: 'san_jose', name: 'San Jose', country: 'United States', timezone: 'PST', latitude: 37.3382, longitude: -121.8863),
      CityInfo(id: 'seattle', name: 'Seattle', country: 'United States', timezone: 'PST', latitude: 47.6062, longitude: -122.3321),
      CityInfo(id: 'portland', name: 'Portland', country: 'United States', timezone: 'PST', latitude: 45.5152, longitude: -122.6784),
    ],
  };

  /// Initialize and load data from JSON
  Future<void> initializeData() async {
    if (_isDataLoaded) return;

    try {
      final String response = await rootBundle.loadString('assets/ekadashi_data.json');
      _rawData = json.decode(response);
      _isDataLoaded = true;
      debugPrint("✅ Ekadashi Data Initialized Successfully (${_rawData?['ekadashis']?.length} events)");
    } catch (e) {
      debugPrint("❌ Critical Error loading Ekadashi data: $e");
      _rawData = {'ekadashis': []};
      _isDataLoaded = true;
    }
  }

  /// Load data directly from parsed Map (useful for tests and offline seeds)
  void loadDataFromJson(Map<String, dynamic> data) {
    _rawData = data;
    _isDataLoaded = true;
    _cache.clear();
  }

  /// Centralized tradition resolver (EC2-FR-052 / EC2-FR-053 / Phase 20)
  /// Resolves observance strictly from vetted content without inferring or altering dates.
  ResolvedEkadashiObservance resolveEkadashiObservance({
    required EkadashiDate event,
    required AppTradition userTradition,
    String? region,
  }) {
    if (!event.hasTraditionVariation || event.traditionVariants.isEmpty) {
      return ResolvedEkadashiObservance(
        primary: event,
        alternate: null,
        hasTraditionVariation: false,
        activeTradition: userTradition,
        sourceStatus: 'verified',
      );
    }

    if (userTradition == AppTradition.general) {
      final alternateVariant = event.traditionVariants[AppTradition.vaishnava] ??
          event.traditionVariants[AppTradition.smarta];

      return ResolvedEkadashiObservance(
        primary: event,
        alternate: alternateVariant,
        hasTraditionVariation: true,
        activeTradition: AppTradition.general,
        variationNote: 'Observance may vary by tradition or region.',
        sourceStatus: 'verified',
      );
    }

    // Specific tradition selected (Smarta or Vaishnava)
    final selectedVariant = event.traditionVariants[userTradition];
    final otherTradition = (userTradition == AppTradition.smarta)
        ? AppTradition.vaishnava
        : AppTradition.smarta;
    final alternateVariant = event.traditionVariants[otherTradition];

    if (selectedVariant != null) {
      final resolvedPrimary = event.copyWith(
        date: selectedVariant.date,
        fastStartTime: selectedVariant.fastStartTime.isNotEmpty ? selectedVariant.fastStartTime : event.fastStartTime,
        fastBreakTime: selectedVariant.fastBreakTime.isNotEmpty ? selectedVariant.fastBreakTime : event.fastBreakTime,
        fastingStartIso: selectedVariant.fastingStartIso.isNotEmpty ? selectedVariant.fastingStartIso : event.fastingStartIso,
        paranaStartIso: selectedVariant.paranaStartIso.isNotEmpty ? selectedVariant.paranaStartIso : event.paranaStartIso,
        paranaEndIso: selectedVariant.paranaEndIso.isNotEmpty ? selectedVariant.paranaEndIso : event.paranaEndIso,
        fastingRules: selectedVariant.fastingRules.isNotEmpty ? selectedVariant.fastingRules : event.fastingRules,
      );

      return ResolvedEkadashiObservance(
        primary: resolvedPrimary,
        alternate: alternateVariant,
        hasTraditionVariation: true,
        activeTradition: userTradition,
        sourceStatus: 'verified',
      );
    }

    return ResolvedEkadashiObservance(
      primary: event,
      alternate: alternateVariant,
      hasTraditionVariation: false,
      activeTradition: userTradition,
      variationNote: 'Observance may vary by tradition or region.',
      sourceStatus: 'standard',
    );
  }

  /// Get Ekadashi list for a specific timezone, language, tradition preference, and location.
  /// When location is provided, uses PanchangCalculator to perform topocentric astronomical calculations!
  List<EkadashiDate> getEkadashis({
    required String timezone,
    required String languageCode,
    AppTradition tradition = AppTradition.general,
    LocationData? location,
  }) {
    if (!_isDataLoaded || _rawData == null) {
      debugPrint("WARNING: Data not loaded yet. Returning empty list.");
      return [];
    }

    // Check cache first
    final locKey = location != null
        ? '${location.city}_${location.latitude.toStringAsFixed(2)}_${location.longitude.toStringAsFixed(2)}'
        : 'default';
    final cacheKey = '${locKey}_${timezone}_${languageCode}_${tradition.name}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

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

        final nameText = names[languageCode] as String? ?? names['en'] as String? ?? '';
        final descText = descriptions[languageCode] as String? ?? descriptions['en'] as String? ?? '';
        final storyText = stories[languageCode] as String? ?? stories['en'] as String? ?? 'Story coming soon...';
        final ruleText = rules[languageCode] as String? ?? rules['en'] as String? ?? 'Standard Ekadashi fasting rules apply.';
        final benefitText = benefitsMap[languageCode] as String? ?? benefitsMap['en'] as String? ?? 'Grants spiritual merit.';

        // Parse tradition tags & variants
        final rawTags = ekadashiJson['tradition_tags'] as List<dynamic>? ?? ['general', 'smarta', 'vaishnava'];
        final traditionTags = rawTags.map((t) => t.toString()).toList();
        final rawRegionTags = ekadashiJson['region_tags'] as List<dynamic>? ?? ['pan-india'];
        final regionTags = rawRegionTags.map((r) => r.toString()).toList();
        final hasVariation = ekadashiJson['has_tradition_variation'] as bool? ?? false;

        // Base timings from verified dataset
        var fastingStartIso = timing['fasting_start'] as String? ?? '';
        var paranaStartIso = timing['parana_start'] as String? ?? '';
        var paranaEndIso = timing['parana_end'] as String? ?? '';
        final dateStr = timing['date'] as String? ?? '';
        var date = DateTime.tryParse(dateStr) ?? DateTime.now();

        var fastStartTime = _formatTimeFromIso(fastingStartIso);
        var fastBreakTime = _formatParanaWindow(paranaStartIso, paranaEndIso);

        // Location-aware calculation if location is available and tithi boundaries exist
        final tithi = ekadashiJson['tithi'] as Map<String, dynamic>?;
        CalculatedEkadashiObservance? calculated;
        CalculatedEkadashiObservance? calculatedSmarta;
        CalculatedEkadashiObservance? calculatedVaishnava;

        final tzOffset = _getUtcOffset(timezone);

        if (location != null && tithi != null && tithi['ekadashi_start'] != null) {
          try {
            final ekStart = DateTime.parse(tithi['ekadashi_start'] as String);
            final ekEnd = DateTime.parse(tithi['ekadashi_end'] as String);
            final dwEnd = DateTime.parse(tithi['dwadashi_end'] as String);
            final daEnd = DateTime.parse(tithi['dashami_end'] as String);

            calculated = PanchangCalculator.resolveObservance(
              ekadashiStartUtc: ekStart,
              ekadashiEndUtc: ekEnd,
              dwadashiEndUtc: dwEnd,
              dashamiEndUtc: daEnd,
              latitude: location.latitude,
              longitude: location.longitude,
              tradition: tradition,
              utcOffset: tzOffset,
              defaultDate: date,
            );

            calculatedSmarta = PanchangCalculator.resolveObservance(
              ekadashiStartUtc: ekStart,
              ekadashiEndUtc: ekEnd,
              dwadashiEndUtc: dwEnd,
              dashamiEndUtc: daEnd,
              latitude: location.latitude,
              longitude: location.longitude,
              tradition: AppTradition.smarta,
              utcOffset: tzOffset,
              defaultDate: date,
            );

            calculatedVaishnava = PanchangCalculator.resolveObservance(
              ekadashiStartUtc: ekStart,
              ekadashiEndUtc: ekEnd,
              dwadashiEndUtc: dwEnd,
              dashamiEndUtc: daEnd,
              latitude: location.latitude,
              longitude: location.longitude,
              tradition: AppTradition.vaishnava,
              utcOffset: tzOffset,
              defaultDate: date,
            );

            // DEFECT 1 FIX: Use calculated observance date when calculation is valid and event has no fixed variant
            if (!hasVariation) {
              date = calculated.observanceDate;
            }
            fastStartTime = calculated.fastStartTimeStr;
            fastBreakTime = calculated.paranaWindowStr;
            fastingStartIso = calculated.fastingStartIso;
            paranaStartIso = calculated.paranaStartIso;
            paranaEndIso = calculated.paranaEndIso;
          } catch (ex) {
            debugPrint("Panchang calculation fallback for event ${ekadashiJson['id']}: $ex");
            // Safe fallback: preserves existing date, fastStartTime, fastBreakTime from JSON
          }
        }

        // Build tradition variants
        final Map<AppTradition, TraditionVariant> variants = {};
        final rawVariants = ekadashiJson['tradition_variants'] as Map<String, dynamic>? ?? {};

        for (var entry in rawVariants.entries) {
          final tKey = entry.key;
          final tMap = entry.value as Map<String, dynamic>? ?? {};
          final appTradition = AppTradition.fromId(tKey);
          final tTiming = tMap['timing']?[timezone];

          if (tTiming != null) {
            var tDateStr = tTiming['date'] as String? ?? '';
            var tDate = DateTime.tryParse(tDateStr) ?? date;
            var tFastStartIso = tTiming['fasting_start'] as String? ?? '';
            var tParanaStartIso = tTiming['parana_start'] as String? ?? '';
            var tParanaEndIso = tTiming['parana_end'] as String? ?? '';
            var tFastStartTime = _formatTimeFromIso(tFastStartIso);
            var tFastBreakTime = _formatParanaWindow(tParanaStartIso, tParanaEndIso);

            // DEFECT 2 FIX: Recalculate topocentric sunrise and Parana window for tradition variants
            if (location != null && tithi != null && tithi['ekadashi_end'] != null && tithi['dwadashi_end'] != null) {
              try {
                final ekEnd = DateTime.parse(tithi['ekadashi_end'] as String);
                final dwEnd = DateTime.parse(tithi['dwadashi_end'] as String);

                // Compute location-specific topocentric sunrise for the variant fasting date
                final tSunrise = PanchangCalculator.calculateSunrise(
                  latitude: location.latitude,
                  longitude: location.longitude,
                  date: tDate,
                  utcOffset: tzOffset,
                );
                if (tSunrise != null) {
                  tFastStartTime = PanchangCalculator.formatTime(tSunrise);
                  tFastStartIso = PanchangCalculator.toIsoString(tSunrise, offset: _getIsoOffsetString(tzOffset));
                }

                // Compute location-specific Parana window for the variant fasting date
                final paranaCalc = PanchangCalculator.calculateParanaWindow(
                  fastingDate: tDate,
                  ekadashiEndUtc: ekEnd,
                  dwadashiEndUtc: dwEnd,
                  latitude: location.latitude,
                  longitude: location.longitude,
                  utcOffset: tzOffset,
                );

                // Only use dynamic Parana calculation if it produces a valid morning window on the Parana day
                final pStart = paranaCalc.paranaStart;
                final pEnd = paranaCalc.paranaEnd;
                final paranaDate = tDate.add(const Duration(days: 1));
                final isValidMorningWindow = pStart.year == paranaDate.year &&
                    pStart.month == paranaDate.month &&
                    pStart.day == paranaDate.day &&
                    pStart.hour < 13 &&
                    pEnd.isAfter(pStart);

                if (isValidMorningWindow) {
                  tFastBreakTime = paranaCalc.paranaWindowStr;
                  tParanaStartIso = paranaCalc.paranaStartIso;
                  tParanaEndIso = paranaCalc.paranaEndIso;
                }
              } catch (e) {
                debugPrint("Variant parana calculation fallback for event ${ekadashiJson['id']}: $e");
                // Safe fallback: preserves existing tFastBreakTime, tParanaStartIso, tParanaEndIso from JSON
              }
            } else if (location != null) {
              final tSunrise = PanchangCalculator.calculateSunrise(
                latitude: location.latitude,
                longitude: location.longitude,
                date: tDate,
                utcOffset: tzOffset,
              );
              if (tSunrise != null) {
                tFastStartTime = PanchangCalculator.formatTime(tSunrise);
              }
            }

            final tRulesMap = tMap['fasting_rules'] as Map<String, dynamic>? ?? {};
            final tRules = tRulesMap[languageCode] as String? ??
                tRulesMap['en'] as String? ??
                ruleText;

            variants[appTradition] = TraditionVariant(
              tradition: appTradition,
              date: tDate,
              fastStartTime: tFastStartTime,
              fastBreakTime: tFastBreakTime,
              fastingStartIso: tFastStartIso,
              paranaStartIso: tParanaStartIso,
              paranaEndIso: tParanaEndIso,
              fastingRules: tRules,
              source: tMap['source'] as String? ?? 'vetted',
            );
          }
        }

        // If topocentric calculation reveals different observance dates between Smarta and Vaishnava,
        // ensure tradition variants are populated so user can view the alternate tradition's date.
        if (calculatedSmarta != null && calculatedVaishnava != null &&
            calculatedSmarta.observanceDate != calculatedVaishnava.observanceDate) {
          final cSmarta = calculatedSmarta;
          final cVaishnava = calculatedVaishnava;
          variants.putIfAbsent(
            AppTradition.smarta,
            () => TraditionVariant(
              tradition: AppTradition.smarta,
              date: cSmarta.observanceDate,
              fastStartTime: cSmarta.fastStartTimeStr,
              fastBreakTime: cSmarta.paranaWindowStr,
              fastingStartIso: cSmarta.fastingStartIso,
              paranaStartIso: cSmarta.paranaStartIso,
              paranaEndIso: cSmarta.paranaEndIso,
              fastingRules: ruleText,
              source: 'calculated',
            ),
          );
          variants.putIfAbsent(
            AppTradition.vaishnava,
            () => TraditionVariant(
              tradition: AppTradition.vaishnava,
              date: cVaishnava.observanceDate,
              fastStartTime: cVaishnava.fastStartTimeStr,
              fastBreakTime: cVaishnava.paranaWindowStr,
              fastingStartIso: cVaishnava.fastingStartIso,
              paranaStartIso: cVaishnava.paranaStartIso,
              paranaEndIso: cVaishnava.paranaEndIso,
              fastingRules: ruleText,
              source: 'calculated',
            ),
          );
        }

        final baseEkadashi = EkadashiDate(
          id: ekadashiJson['id'] as int? ?? 0,
          name: nameText,
          date: date,
          fastStartTime: fastStartTime,
          fastBreakTime: fastBreakTime,
          description: descText,
          story: storyText,
          fastingRules: ruleText,
          benefits: benefitText,
          paksha: ekadashiJson['paksha'] as String? ?? '',
          month: ekadashiJson['month'] as String? ?? '',
          fastingStartIso: fastingStartIso,
          paranaStartIso: paranaStartIso,
          paranaEndIso: paranaEndIso,
          traditionVariants: variants,
          traditionTags: traditionTags,
          regionTags: regionTags,
          hasTraditionVariation: (hasVariation && variants.isNotEmpty) ||
              (calculatedSmarta != null && calculatedVaishnava != null &&
               calculatedSmarta.observanceDate != calculatedVaishnava.observanceDate),
        );

        // Resolve observance based on tradition
        final resolved = resolveEkadashiObservance(
          event: baseEkadashi,
          userTradition: tradition,
        );

        ekadashis.add(resolved.primary);
      } catch (e) {
        debugPrint("Error parsing Ekadashi: $e");
      }
    }

    // Sort strictly by date
    ekadashis.sort((a, b) => a.date.compareTo(b.date));

    // Cache the result
    _cache[cacheKey] = ekadashis;

    return ekadashis;
  }

  /// Format ISO datetime to display time (e.g., "06:40 AM")
  String _formatTimeFromIso(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final tIndex = isoString.indexOf('T');
      if (tIndex == -1 || tIndex >= isoString.length - 1) return '';

      String timePart = isoString.substring(tIndex + 1);
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

  /// Get UTC offset Duration for a given timezone code
  Duration _getUtcOffset(String timezone) {
    switch (timezone) {
      case 'EST':
        return const Duration(hours: -5);
      case 'CST':
        return const Duration(hours: -6);
      case 'MST':
        return const Duration(hours: -7);
      case 'PST':
        return const Duration(hours: -8);
      case 'IST':
      default:
        return const Duration(hours: 5, minutes: 30);
    }
  }

  /// Format Duration to ISO 8601 offset string (e.g. "+05:30" or "-05:00")
  String _getIsoOffsetString(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
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
    return 'IST';
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
    final indian = IndianCitiesData.getCityById(cityId);
    if (indian != null) {
      return CityInfo(
        id: indian.id,
        name: '${indian.name} (${indian.state})',
        country: 'India',
        timezone: indian.timezone,
        state: indian.state,
        latitude: indian.latitude,
        longitude: indian.longitude,
      );
    }
    return null;
  }

  /// Get Ekadashis with default parameters
  Future<List<EkadashiDate>> getUpcomingEkadashis({
    String languageCode = 'en',
    String timezone = 'IST',
    AppTradition tradition = AppTradition.general,
    LocationData? location,
  }) async {
    if (!_isDataLoaded) await initializeData();
    return getEkadashis(
      timezone: timezone,
      languageCode: languageCode,
      tradition: tradition,
      location: location,
    );
  }

  /// Clear cache (useful when language, location, or tradition changes)
  void clearCache() {
    _cache.clear();
  }

  /// Get the best matching app timezone based on device's system timezone.
  Future<String> getDeviceAppTimezone() async {
    try {
      final systemTimezone = await FlutterTimezone.getLocalTimezone();
      debugPrint('📍 Device system timezone: $systemTimezone');

      const Map<String, String> timezoneMapping = {
        'Asia/Kolkata': 'IST',
        'Asia/Calcutta': 'IST',
        'America/New_York': 'EST',
        'America/Detroit': 'EST',
        'America/Toronto': 'EST',
        'America/Indiana/Indianapolis': 'EST',
        'America/Kentucky/Louisville': 'EST',
        'America/Chicago': 'CST',
        'America/Winnipeg': 'CST',
        'America/Mexico_City': 'CST',
        'America/Denver': 'MST',
        'America/Edmonton': 'MST',
        'America/Phoenix': 'MST',
        'America/Boise': 'MST',
        'America/Los_Angeles': 'PST',
        'America/Vancouver': 'PST',
        'America/Seattle': 'PST',
        'America/Tijuana': 'PST',
      };

      if (timezoneMapping.containsKey(systemTimezone)) {
        final appTimezone = timezoneMapping[systemTimezone]!;
        debugPrint('📍 Matched timezone: $systemTimezone → $appTimezone');
        return appTimezone;
      }

      if (systemTimezone.startsWith('America/')) {
        if (systemTimezone.contains('New_York') ||
            systemTimezone.contains('Detroit') ||
            systemTimezone.contains('Toronto') ||
            systemTimezone.contains('Indiana') ||
            systemTimezone.contains('Kentucky')) {
          return 'EST';
        }
        if (systemTimezone.contains('Chicago') ||
            systemTimezone.contains('Winnipeg') ||
            systemTimezone.contains('Mexico')) {
          return 'CST';
        }
        if (systemTimezone.contains('Denver') ||
            systemTimezone.contains('Phoenix') ||
            systemTimezone.contains('Edmonton') ||
            systemTimezone.contains('Boise')) {
          return 'MST';
        }
        if (systemTimezone.contains('Los_Angeles') ||
            systemTimezone.contains('Vancouver') ||
            systemTimezone.contains('Seattle') ||
            systemTimezone.contains('Portland')) {
          return 'PST';
        }
      }

      if (systemTimezone.startsWith('Asia/')) {
        return 'IST';
      }

      return 'IST';
    } catch (e) {
      debugPrint('⚠️ Error getting device timezone: $e');
      return 'IST';
    }
  }
}