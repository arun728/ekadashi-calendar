import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/place_names.dart';
import 'ekadashi_settings.dart';
import 'native_location_service.dart';
import 'panchang/panchang_city.dart';

/// Any place in the app language, never in Latin letters outside English
/// (AppModel.placeName on iOS): the shared table first, then the phone's
/// geocoder in that language at the place's coordinates (saved on the
/// phone; one lookup at a time), and meanwhile the name written by sound.
/// Listeners hear when a geocoded name arrives.
class PlaceNameResolver extends ChangeNotifier {
  PlaceNameResolver({NativeLocationService? geocoder})
    : _geocoder = geocoder ?? NativeLocationService();

  static final instance = PlaceNameResolver();
  static const savedKey = 'geocoded_place_names';

  final NativeLocationService _geocoder;
  final _names = <String, String>{};
  final _lookups = <String>{};
  Future<void>? _loading;
  Future<void> _queue = Future.value();

  /// Reads the names saved by earlier lookups once.
  Future<void> load() => _loading ??= () async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(savedKey);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach(
          (key, value) => _names.putIfAbsent(key, () => value as String),
        );
        notifyListeners();
      }
    } catch (_) {}
  }();

  /// [name] (a place at [latitude], [longitude]) in [language].
  String place(
    String name,
    String language, {
    required double latitude,
    required double longitude,
  }) {
    final table = PlaceNames.place(name, language);
    if (PlaceNames.isKnown(name, language)) return table;
    final key =
        '$language|$name|${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';
    final known = _names[key];
    if (known != null) return known;
    if (_lookups.add(key)) {
      load();
      _queue = _queue.then((_) => _lookup(key, language, latitude, longitude));
    }
    return table;
  }

  Future<void> _lookup(
    String key,
    String language,
    double latitude,
    double longitude,
  ) async {
    try {
      final found = await _geocoder.localizedCityName(
        latitude,
        longitude,
        language,
      );
      // Only a name in the language's own script replaces English.
      if (found == null || RegExp('[A-Za-z]').hasMatch(found)) return;
      _names[key] = found;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final saved = <String, dynamic>{};
      try {
        saved.addAll(
          jsonDecode(prefs.getString(savedKey) ?? '{}') as Map<String, dynamic>,
        );
      } catch (_) {}
      saved[key] = found;
      await prefs.setString(savedKey, jsonEncode(saved));
    } catch (_) {}
  }

  /// A city and its country in [language] ("சென்னை (இந்தியா)").
  String city(PanchangCity city, String language) {
    final (name, code) = EkadashiSettings.splitCountry(city.label);
    final local = place(
      name,
      language,
      latitude: city.latitude,
      longitude: city.longitude,
    );
    return code == null
        ? local
        : '$local (${PlaceNames.country(code, language)})';
  }
}
