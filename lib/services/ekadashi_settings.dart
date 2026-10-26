import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/place_names.dart';
import 'ekadashi_schedule.dart';
import 'ekadashi_service.dart';
import 'native_location_service.dart';
import 'panchang/calculated_ekadashi.dart';
import 'panchang/panchang_city.dart';
import 'panchang/panchang_location_store.dart';

/// Where and how Home, Calendar, reminders, widgets and Journey calculate
/// Ekadashis (AppModel.swift): the city (picked, else last detected, else
/// Chennai), the tradition (Smarta or Vaishnava) and the year shown.
/// Choosing a city here also sets the Panchang location, not the reverse.
class EkadashiSettings extends ChangeNotifier {
  static const cityKey = 'ekadashi_city';
  static const manualKey = 'ekadashi_city_manual';
  static const traditionKey = 'ekadashi_tradition';
  static const yearKey = 'ekadashi_year';
  static const detectedCityId = 'detected';
  static const defaultCity = PanchangCity(
    id: 'geonames-1264527',
    label: 'Chennai (IN)',
    latitude: 13.08784,
    longitude: 80.27847,
  );

  PanchangCity city = defaultCity;
  bool isManual = false;
  EkadashiTradition tradition = EkadashiTradition.gaudiya;
  List<int> years = EkadashiYears.fallback;
  int year = EkadashiYears.defaultYear(DateTime.now(), EkadashiYears.fallback);

  /// Bumped when Home sets the Panchang location; an open Panchang tab follows.
  int panchangCityRevision = 0;
  bool loaded = false;

  Future<void> load() async {
    years = await EkadashiYears.load();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cityKey);
    if (raw != null) {
      try {
        city =
            PanchangLocationStore.fromJson(
              jsonDecode(raw) as Map<String, dynamic>,
            ) ??
            defaultCity;
      } catch (_) {}
    }
    isManual = prefs.getBool(manualKey) ?? false;
    tradition = EkadashiTradition.values.firstWhere(
      (t) => t.name == prefs.getString(traditionKey),
      orElse: () => EkadashiTradition.gaudiya,
    );
    final saved = prefs.getInt(yearKey);
    year = saved != null && years.contains(saved)
        ? saved
        : EkadashiYears.defaultYear(DateTime.now(), years);
    loaded = true;
    notifyListeners();
  }

  Future<void> _saveCity(PanchangCity value, {required bool manual}) async {
    city = value;
    isManual = manual;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cityKey,
      jsonEncode(PanchangLocationStore.toJson(value)),
    );
    await prefs.setBool(manualKey, manual);
  }

  /// The user picked a city on Home: Ekadashis follow it, detection no
  /// longer replaces it, and the Panchang tab moves there too.
  Future<void> chooseCity(PanchangCity value) async {
    await _saveCity(value, manual: true);
    await RecentCities.add(value);
    await savePanchangCity(value);
  }

  /// Sets the Panchang location; an open Panchang tab follows.
  Future<void> savePanchangCity(PanchangCity value) async {
    try {
      await PanchangLocationStore().save(value);
    } catch (_) {}
    panchangCityRevision++;
    notifyListeners();
  }

  /// "Use current location": detection decides again.
  Future<void> clearManual() async {
    isManual = false;
    await (await SharedPreferences.getInstance()).setBool(manualKey, false);
    notifyListeners();
  }

  /// A detected place becomes the Ekadashi city unless the user chose one
  /// since the app opened: at a launch ([atLaunch]) the place found now wins
  /// over a picked city, as in v1. Returns true when the city changed.
  Future<bool> useDetected(LocationData fix, {bool atLaunch = false}) async {
    if (isManual && !atLaunch) return false;
    final detected = await cityFromFix(fix);
    if (detected == null) return false;
    final previous = city;
    final changed =
        detected.latitude != city.latitude ||
        detected.longitude != city.longitude ||
        detected.timeZoneId != city.timeZoneId ||
        detected.label != city.label;
    await _saveCity(detected, manual: false);
    final panchang = await PanchangLocationStore().load();
    if (panchang == null) {
      // The Panchang tab starts from the detected place until one is set there.
      await savePanchangCity(detected);
    } else if (atLaunch && changed && panchang == previous) {
      // Panchang showed Home's city: it moves with Home.
      await savePanchangCity(detected);
    }
    if (changed) notifyListeners();
    return changed;
  }

  /// A location fix as a city: the geocoded name with the nearest catalog
  /// city's country code ("Chennai (IN)") and its IANA zone, rounded to about
  /// a kilometre so GPS drift reuses the cached schedule.
  static Future<PanchangCity?> cityFromFix(LocationData fix) async {
    PanchangCity? nearest;
    try {
      nearest = await PanchangLocationStore.nearest(
        fix.latitude,
        fix.longitude,
      );
    } catch (_) {
      // Without the catalog: the detected name in India's zone.
    }
    final code = nearest == null ? null : splitCountry(nearest.label).$2;
    final name = fix.city.isEmpty
        ? (nearest == null ? '—' : splitCountry(nearest.label).$1)
        : fix.city;
    double rounded(double v) => (v * 100).roundToDouble() / 100;
    final city = PanchangCity(
      id: detectedCityId,
      label: code == null ? name : '$name ($code)',
      latitude: rounded(fix.latitude),
      longitude: rounded(fix.longitude),
      timeZoneId: nearest?.timeZoneId ?? 'Asia/Kolkata',
    );
    try {
      city.validate();
      return city;
    } catch (_) {
      return null;
    }
  }

  Future<void> setTradition(EkadashiTradition value) async {
    if (value == tradition) return;
    tradition = value;
    await (await SharedPreferences.getInstance()).setString(
      traditionKey,
      value.name,
    );
    notifyListeners();
  }

  Future<void> setYear(int value) async {
    if (!years.contains(value) || value == year) return;
    year = value;
    await (await SharedPreferences.getInstance()).setInt(yearKey, value);
    notifyListeners();
  }

  /// The tradition's name key: "Smarta" or "Vaishnava" everywhere.
  String get traditionNameKey => traditionKeyFor(tradition);

  static String traditionKeyFor(EkadashiTradition? value) =>
      value == EkadashiTradition.gaudiya
      ? 'tradition_vaishnava'
      : 'tradition_smarta';

  /// Every enabled year's Ekadashis at the city for the tradition in
  /// [language], from what is already calculated (empty before that).
  List<EkadashiDate> cachedEkadashis(String language) =>
      EkadashiService().cachedEngineEkadashis(
        city: city,
        tradition: tradition,
        languageCode: language,
        years: years,
      );

  /// "Chennai (IN)" → ("Chennai", "IN").
  static (String, String?) splitCountry(String label) {
    final match = RegExp(r' \(([A-Z]{2})\)$').firstMatch(label);
    if (match == null) return (label, null);
    return (label.substring(0, match.start), match.group(1));
  }

  /// A catalog city and its country in [language] ("சென்னை (இந்தியா)"),
  /// for search; on screen PlaceNameResolver also asks the geocoder.
  static String displayName(PanchangCity city, String language) =>
      PlaceNames.label(city.label, language);
}
