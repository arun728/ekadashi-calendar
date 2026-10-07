import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Explicit coordinates and IANA timezone; never uses the host timezone.
class PanchangCity {
  const PanchangCity({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.timeZoneId = 'Asia/Kolkata',
    this.searchTerms = '',
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;

  final String timeZoneId;
  final String searchTerms;
  static Map<String, tz.Location>? _zones;

  tz.Location get zone {
    if (_zones == null) {
      // Notification scheduling also uses package:timezone. Preserve its local
      // zone and retain our own complete catalog if another service reloads it.
      tz.Location previousLocal;
      try {
        previousLocal = tz.local;
      } catch (_) {
        previousLocal = tz.UTC;
      }
      tzdata.initializeTimeZones();
      _zones = Map.unmodifiable(tz.timeZoneDatabase.locations);
      tz.setLocalLocation(previousLocal);
    }
    if (!timeZoneId.contains('/') && timeZoneId != 'UTC') {
      throw ArgumentError('Use an IANA timezone such as Asia/Kolkata');
    }
    try {
      return _zones![timeZoneId] ??
          (throw ArgumentError('Unknown timezone: $timeZoneId'));
    } catch (_) {
      throw ArgumentError('Unknown timezone: $timeZoneId');
    }
  }

  void validate() {
    if (!latitude.isFinite ||
        latitude.abs() > 90 ||
        !longitude.isFinite ||
        longitude.abs() > 180 ||
        label.trim().isEmpty) {
      throw ArgumentError('Invalid location coordinates or name');
    }
    zone;
  }

  DateTime wallClock(DateTime instant) =>
      tz.TZDateTime.from(instant.toUtc(), zone);
  DateTime midnight(DateTime date, {int dayOffset = 0}) =>
      tz.TZDateTime(zone, date.year, date.month, date.day + dayOffset).toUtc();
  DateTime dateAtHour(DateTime date, int hour) =>
      tz.TZDateTime(zone, date.year, date.month, date.day, hour).toUtc();

  String get timezoneLabel => timeZoneId == 'Asia/Kolkata' ? 'IST' : timeZoneId;

  static const newDelhi = PanchangCity(
    id: 'new-delhi',
    label: 'New Delhi',
    latitude: 28.6139,
    longitude: 77.2090,
  );
  static const mumbai = PanchangCity(
    id: 'mumbai',
    label: 'Mumbai',
    latitude: 19.0760,
    longitude: 72.8777,
  );
  static const chennai = PanchangCity(
    id: 'chennai',
    label: 'Chennai',
    latitude: 13.0827,
    longitude: 80.2707,
  );
  static const kolkata = PanchangCity(
    id: 'kolkata',
    label: 'Kolkata',
    latitude: 22.5726,
    longitude: 88.3639,
  );
  static const bengaluru = PanchangCity(
    id: 'bengaluru',
    label: 'Bengaluru',
    latitude: 12.9716,
    longitude: 77.5946,
  );
  static const hyderabad = PanchangCity(
    id: 'hyderabad',
    label: 'Hyderabad',
    latitude: 17.3850,
    longitude: 78.4867,
  );
  static const pune = PanchangCity(
    id: 'pune',
    label: 'Pune',
    latitude: 18.5204,
    longitude: 73.8567,
  );
  static const varanasi = PanchangCity(
    id: 'varanasi',
    label: 'Varanasi',
    latitude: 25.3176,
    longitude: 82.9739,
  );

  static const london = PanchangCity(
    id: 'london',
    label: 'London',
    latitude: 51.5074,
    longitude: -0.1278,
    timeZoneId: 'Europe/London',
  );
  static const newYork = PanchangCity(
    id: 'new-york',
    label: 'New York',
    latitude: 40.7128,
    longitude: -74.006,
    timeZoneId: 'America/New_York',
  );
  static const sydney = PanchangCity(
    id: 'sydney',
    label: 'Sydney',
    latitude: -33.8688,
    longitude: 151.2093,
    timeZoneId: 'Australia/Sydney',
  );

  static const supported = <PanchangCity>[
    newDelhi,
    mumbai,
    chennai,
    kolkata,
    bengaluru,
    hyderabad,
    pune,
    varanasi,
    london,
    newYork,
    sydney,
  ];

  @override
  bool operator ==(Object other) =>
      other is PanchangCity &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timeZoneId == timeZoneId &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, latitude, longitude, timeZoneId, label);
}
