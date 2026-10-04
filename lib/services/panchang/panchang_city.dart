/// A supported Indian observance location. Panchang calculations always use
/// IST; coordinates only determine local sunrise, sunset and moonrise.
class PanchangCity {
  const PanchangCity({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;

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

  static const supported = <PanchangCity>[
    newDelhi,
    mumbai,
    chennai,
    kolkata,
    bengaluru,
    hyderabad,
    pune,
    varanasi,
  ];

  @override
  bool operator ==(Object other) => other is PanchangCity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
