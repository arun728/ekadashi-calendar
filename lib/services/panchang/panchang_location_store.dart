import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'panchang_city.dart';

class PanchangLocationStore {
  static const key = 'panchang_location';
  static Future<List<PanchangCity>>? _catalog;
  static List<PanchangCity>? _loaded;

  /// The worldwide catalog, read once. Kept as a list so later callers get a
  /// future of their own (widget tests run on a fake clock).
  static Future<List<PanchangCity>> cities() async {
    final known = _loaded;
    if (known != null) return known;
    try {
      return _loaded = await (_catalog ??= _loadCities());
    } catch (_) {
      _catalog = null; // A failed read is tried again next time.
      rethrow;
    }
  }

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

  /// Cities offered before anything is typed: where most users live, India
  /// first, then the diaspora (GeoNames ids, as CityShortlist.swift).
  static const popularIds = [
    '1264527', '1261481', '1275339', '1277333', '1269843', '1275004', //
    '1259229', '1279233', '1253405', '1269515', '5128581', '5097529', //
    '5368361', '5391959', '4887398', '4699066', '5809844', '4180439', //
    '4140963', '6167865', '6173331', '2643743', '2925533', '2988507', //
    '292223', '290030', '1880252', '1735161', '2147714', '2158177', //
    '2063523', '2193733', '993800', '184745', '1283240', '1248991', //
    '934154',
  ];

  /// The popular cities, in the order above.
  static Future<List<PanchangCity>> popular() async {
    final byId = {for (final c in await cities()) c.id: c};
    return [
      for (final id in popularIds)
        if (byId['geonames-$id'] != null) byId['geonames-$id']!,
    ];
  }

  /// The closest catalog city, for naming a location fix without a network.
  static Future<PanchangCity?> nearest(
    double latitude,
    double longitude,
  ) async {
    PanchangCity? best;
    var bestDistance = double.infinity;
    for (final c in await cities()) {
      final d =
          (c.latitude - latitude) * (c.latitude - latitude) +
          (c.longitude - longitude) * (c.longitude - longitude);
      if (d < bestDistance) {
        bestDistance = d;
        best = c;
      }
    }
    return best;
  }

  /// Names, ASCII names, country codes and names typed in [language].
  static Future<List<PanchangCity>> search(
    String query,
    String Function(PanchangCity) localized, {
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    return (await cities())
        .where(
          (c) => '${c.label.toLowerCase()} ${c.searchTerms} ${localized(c)}'
              .contains(q),
        )
        .take(limit)
        .toList();
  }

  static Map<String, dynamic> toJson(PanchangCity city) => {
    'id': city.id,
    'label': city.label,
    'latitude': city.latitude,
    'longitude': city.longitude,
    'timezone': city.timeZoneId,
  };

  static PanchangCity? fromJson(Map<String, dynamic> data) {
    try {
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
      return null;
    }
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

/// The cities picked in the city picker, newest first (at most [limit]),
/// shown above the popular cities (CityShortlist.swift `RecentCities`).
class RecentCities {
  static const key = 'ekadashi_recent_cities';
  static const limit = 8;

  static Future<List<PanchangCity>> all() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return [];
      return [
        for (final row in jsonDecode(raw) as List)
          if (PanchangLocationStore.fromJson(row as Map<String, dynamic>)
              case final city?)
            city,
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(PanchangCity city) async {
    final list =
        (await all())
            .where(
              (c) =>
                  c.id != city.id ||
                  c.latitude != city.latitude ||
                  c.longitude != city.longitude,
            )
            .toList()
          ..insert(0, city);
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode([
        for (final c in list.take(limit)) PanchangLocationStore.toJson(c),
      ]),
    );
  }

  /// What the picker shows with an empty query: recent picks, then popular
  /// cities not already among them. Never empty.
  static Future<({List<PanchangCity> recent, List<PanchangCity> popular})>
  shortlist() async {
    final recent = await all();
    final ids = {for (final c in recent) c.id};
    return (
      recent: recent,
      popular: (await PanchangLocationStore.popular())
          .where((c) => !ids.contains(c.id))
          .toList(),
    );
  }
}
