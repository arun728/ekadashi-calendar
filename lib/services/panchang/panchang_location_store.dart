import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'panchang_city.dart';

class PanchangLocationStore {
  static const key = 'panchang_location';
  static Future<List<PanchangCity>>? _catalog;

  static Future<List<PanchangCity>> cities() => _catalog ??= _loadCities();

  static Future<List<PanchangCity>> _loadCities() async {
    final rows =
        jsonDecode(await rootBundle.loadString('assets/panchang/cities.json'))
            as List;
    return List.unmodifiable(
      rows.map(
        (row) => PanchangCity(
          id: 'geonames-${row[0]}',
          searchTerms: '${row[1]} ${row[2]} ${row[3]}'.toLowerCase(),
          label: '${row[1]} (${row[3]})',
          latitude: (row[4] as num).toDouble(),
          longitude: (row[5] as num).toDouble(),
          timeZoneId: row[6] as String,
        ),
      ),
    );
  }

  Future<PanchangCity?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final city = PanchangCity(
        id: data['id'] as String,
        label: data['label'] as String,
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        timeZoneId: data['timezone'] as String,
      );
      city.validate();
      return city;
    } catch (_) {
      return null; // Corrupt/old data never prevents opening Panchang.
    }
  }

  Future<void> save(PanchangCity city) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode({
        'id': city.id,
        'label': city.label,
        'latitude': city.latitude,
        'longitude': city.longitude,
        'timezone': city.timeZoneId,
      }),
    );
    if (!ok) throw StateError('Could not save Panchang location');
  }
}
