import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'indian_cities_data.dart';

/// Native location service that communicates with Kotlin via MethodChannel
/// Replaces the Geolocator plugin to prevent activity recreation freeze issues
class NativeLocationService {
  static final NativeLocationService _instance = NativeLocationService._internal();
  factory NativeLocationService() => _instance;
  NativeLocationService._internal();

  static const MethodChannel _channel = MethodChannel('com.ekadashi.location');

  /// Callback when user selects a new location or location updates
  static void Function(LocationData)? onLocationChanged;

  /// Get current location with automatic fallback to cache or saved manual city
  /// This runs on a background thread in Kotlin - never blocks UI
  Future<LocationData?> getCurrentLocation() async {
    // If auto-detect is disabled, return saved manual location
    final autoDetect = await isAutoDetectEnabled();
    if (!autoDetect) {
      final savedManual = await getSavedUserLocation();
      if (savedManual != null) return savedManual;
    }

    // Check permission first before attempting native location
    final hasPerm = await hasLocationPermission();
    if (!hasPerm) {
      return null;
    }

    try {
      // 40s timeout to cover native 30s timeout + 5s legacy fallback + overhead
      final result = await _channel.invokeMethod<Map>('getCurrentLocation')
          .timeout(const Duration(seconds: 40));
      if (result != null) {
        final map = Map<String, dynamic>.from(result);
        if (map['success'] == true) {
          final lat = map['latitude'] != null
              ? (map['latitude'] as num).toDouble()
              : IndianCitiesData.defaultCity.latitude;
          final lng = map['longitude'] != null
              ? (map['longitude'] as num).toDouble()
              : IndianCitiesData.defaultCity.longitude;
          final nearest = IndianCitiesData.findNearestCity(lat, lng);
          final loc = LocationData(
            latitude: lat,
            longitude: lng,
            city: map['city'] as String? ?? nearest.name,
            timezone: map['timezone'] as String? ?? 'IST',
            state: nearest.state,
          );
          await saveUserLocation(loc);
          return loc;
        } else {
          debugPrint('Location error: ${map['errorCode']} - ${map['errorMessage']}');
        }
      }
    } on TimeoutException {
      debugPrint('⚠️ NativeLocationService.getCurrentLocation TIMEOUT - GPS may be cold starting');
    } catch (e) {
      debugPrint('NativeLocationService.getCurrentLocation error: $e');
    }

    // Fallback to saved user location if any
    return await getSavedUserLocation();
  }

  /// Get cached location instantly (for fast UI response)
  Future<LocationData?> getCachedLocation() async {
    final autoDetect = await isAutoDetectEnabled();
    if (!autoDetect) {
      final savedManual = await getSavedUserLocation();
      if (savedManual != null) return savedManual;
    }

    try {
      final result = await _channel.invokeMethod<Map>('getCachedLocation');
      if (result != null) {
        final map = Map<String, dynamic>.from(result);
        if (map['success'] == true) {
          final lat = map['latitude'] != null
              ? (map['latitude'] as num).toDouble()
              : IndianCitiesData.defaultCity.latitude;
          final lng = map['longitude'] != null
              ? (map['longitude'] as num).toDouble()
              : IndianCitiesData.defaultCity.longitude;
          final nearest = IndianCitiesData.findNearestCity(lat, lng);
          return LocationData(
            latitude: lat,
            longitude: lng,
            city: map['city'] as String? ?? nearest.name,
            timezone: map['timezone'] as String? ?? 'IST',
            state: nearest.state,
          );
        }
      }
    } catch (e) {
      debugPrint('NativeLocationService.getCachedLocation error: $e');
    }

    return await getSavedUserLocation();
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasLocationPermission')
          .timeout(const Duration(milliseconds: 1500)) ?? false;
    } on TimeoutException {
      debugPrint('hasLocationPermission timeout');
      return false;
    } catch (e) {
      debugPrint('hasLocationPermission error: $e');
      return false;
    }
  }

  /// Request location permission (shows system dialog)
  Future<bool> requestLocationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestLocationPermission') ?? false;
    } catch (e) {
      debugPrint('requestLocationPermission error: $e');
      return false;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isLocationEnabled') ?? false;
    } catch (e) {
      debugPrint('isLocationEnabled error: $e');
      return false;
    }
  }

  /// Check if we should show permission rationale
  Future<bool> shouldShowRequestRationale() async {
    try {
      return await _channel.invokeMethod<bool>('shouldShowRequestRationale') ?? false;
    } catch (e) {
      debugPrint('shouldShowRequestRationale error: $e');
      return false;
    }
  }

  /// Get manually selected city ID
  Future<String?> getSelectedCityId() async {
    try {
      final nativeId = await _channel.invokeMethod<String?>('getSelectedCityId');
      if (nativeId != null && nativeId.isNotEmpty) return nativeId;
    } catch (e) {
      debugPrint('getSelectedCityId native error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_city_id');
  }

  /// Set manually selected city ID
  Future<void> setSelectedCityId(String? cityId) async {
    try {
      await _channel.invokeMethod('setSelectedCityId', {'cityId': cityId});
    } catch (e) {
      debugPrint('setSelectedCityId error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    if (cityId != null) {
      await prefs.setString('selected_city_id', cityId);
    } else {
      await prefs.remove('selected_city_id');
    }
  }

  /// Check if auto-detect location is enabled
  Future<bool> isAutoDetectEnabled() async {
    try {
      final nativeVal = await _channel.invokeMethod<bool>('isAutoDetectEnabled');
      if (nativeVal != null) return nativeVal;
    } catch (e) {
      debugPrint('isAutoDetectEnabled native error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_detect_location') ?? true;
  }

  /// Set auto-detect location enabled state
  Future<void> setAutoDetectEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoDetectEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('setAutoDetectEnabled native error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_detect_location', enabled);
  }

  /// Get current timezone code (IST, EST, CST, MST, PST)
  Future<String> getCurrentTimezone() async {
    try {
      return await _channel.invokeMethod<String>('getCurrentTimezone') ?? 'IST';
    } catch (e) {
      debugPrint('getCurrentTimezone error: $e');
      return 'IST';
    }
  }

  /// Set timezone manually (when user selects a city)
  Future<void> setTimezone(String timezone) async {
    try {
      await _channel.invokeMethod('setTimezone', {'timezone': timezone});
    } catch (e) {
      debugPrint('setTimezone error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_timezone', timezone);
  }

  /// Save location to SharedPreferences and native channel
  Future<void> saveUserLocation(LocationData loc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_latitude', loc.latitude);
    await prefs.setDouble('user_longitude', loc.longitude);
    await prefs.setString('user_city', loc.city);
    await prefs.setString('user_state', loc.state);
    await prefs.setString('user_timezone', loc.timezone);

    onLocationChanged?.call(loc);
  }

  /// Select manual city by IndianCity model
  Future<LocationData> selectManualCity(IndianCity city) async {
    await setAutoDetectEnabled(false);
    await setSelectedCityId(city.id);
    await setTimezone(city.timezone);

    final loc = LocationData(
      latitude: city.latitude,
      longitude: city.longitude,
      city: city.name,
      state: city.state,
      timezone: city.timezone,
    );
    await saveUserLocation(loc);
    return loc;
  }

  /// Retrieve saved user location
  Future<LocationData?> getSavedUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('user_latitude');
    final lng = prefs.getDouble('user_longitude');
    final city = prefs.getString('user_city');
    final state = prefs.getString('user_state') ?? '';
    final tz = prefs.getString('user_timezone') ?? 'IST';

    if (lat != null && lng != null && city != null) {
      return LocationData(
        latitude: lat,
        longitude: lng,
        city: city,
        state: state,
        timezone: tz,
      );
    }
    return null;
  }

  /// Clear all cached location data
  Future<void> clearCache() async {
    try {
      await _channel.invokeMethod('clearLocationCache');
    } catch (e) {
      debugPrint('clearCache error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_latitude');
    await prefs.remove('user_longitude');
    await prefs.remove('user_city');
    await prefs.remove('user_state');
  }
}

/// Location data model with State and exact coordinates
class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final String timezone;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    this.state = '',
    required this.timezone,
  });

  LocationData copyWith({
    double? latitude,
    double? longitude,
    String? city,
    String? state,
    String? timezone,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      state: state ?? this.state,
      timezone: timezone ?? this.timezone,
    );
  }

  String get displayName => state.isNotEmpty ? '$city, $state' : city;

  @override
  String toString() => 'LocationData(city: $city, state: $state, timezone: $timezone, lat: $latitude, lng: $longitude)';
}