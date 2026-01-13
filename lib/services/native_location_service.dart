import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native location service that communicates with Kotlin via MethodChannel
/// Replaces the Geolocator plugin to prevent activity recreation freeze issues
class NativeLocationService {
  static final NativeLocationService _instance = NativeLocationService._internal();
  factory NativeLocationService() => _instance;
  NativeLocationService._internal();

  static const MethodChannel _channel = MethodChannel('com.ekadashi.location');

  /// Get current location with automatic fallback to cache
  /// This runs on a background thread in Kotlin - never blocks UI
  Future<LocationData?> getCurrentLocation() async {
    try {
      final result = await _channel.invokeMethod<Map>('getCurrentLocation');
      if (result == null) return null;

      final map = Map<String, dynamic>.from(result);
      if (map['success'] == true) {
        return LocationData(
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
          city: map['city'] as String? ?? 'Unknown',
          timezone: map['timezone'] as String? ?? 'IST',
        );
      } else {
        debugPrint('Location error: ${map['errorCode']} - ${map['errorMessage']}');
        return null;
      }
    } catch (e) {
      debugPrint('NativeLocationService.getCurrentLocation error: $e');
      return null;
    }
  }

  /// Get cached location instantly (for fast UI response)
  Future<LocationData?> getCachedLocation() async {
    try {
      final result = await _channel.invokeMethod<Map>('getCachedLocation');
      if (result == null) return null;

      final map = Map<String, dynamic>.from(result);
      if (map['success'] == true) {
        return LocationData(
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
          city: map['city'] as String? ?? 'Unknown',
          timezone: map['timezone'] as String? ?? 'IST',
        );
      }
      return null;
    } catch (e) {
      debugPrint('NativeLocationService.getCachedLocation error: $e');
      return null;
    }
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasLocationPermission') ?? false;
    } catch (e) {
      debugPrint('hasLocationPermission error: $e');
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

  /// Get manually selected city ID
  Future<String?> getSelectedCityId() async {
    try {
      return await _channel.invokeMethod<String?>('getSelectedCityId');
    } catch (e) {
      debugPrint('getSelectedCityId error: $e');
      return null;
    }
  }

  /// Set manually selected city ID
  Future<void> setSelectedCityId(String? cityId) async {
    try {
      await _channel.invokeMethod('setSelectedCityId', {'cityId': cityId});
    } catch (e) {
      debugPrint('setSelectedCityId error: $e');
    }
  }

  /// Check if auto-detect location is enabled
  Future<bool> isAutoDetectEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAutoDetectEnabled') ?? true;
    } catch (e) {
      debugPrint('isAutoDetectEnabled error: $e');
      return true;
    }
  }

  /// Set auto-detect location enabled state
  Future<void> setAutoDetectEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoDetectEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('setAutoDetectEnabled error: $e');
    }
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
  }

  /// Clear all cached location data
  Future<void> clearCache() async {
    try {
      await _channel.invokeMethod('clearLocationCache');
    } catch (e) {
      debugPrint('clearCache error: $e');
    }
  }
}

/// Location data model
class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String timezone;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.timezone,
  });

  @override
  String toString() => 'LocationData(city: $city, timezone: $timezone, lat: $latitude, lng: $longitude)';
}