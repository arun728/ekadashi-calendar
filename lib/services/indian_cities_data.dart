import 'dart:math' as math;

/// Model for an Indian city with exact geographic coordinates for astronomical calculations
class IndianCity {
  final String id;
  final String name;
  final String state;
  final bool isUnionTerritory;
  final double latitude;
  final double longitude;
  final String timezone;

  const IndianCity({
    required this.id,
    required this.name,
    required this.state,
    this.isUnionTerritory = false,
    required this.latitude,
    required this.longitude,
    this.timezone = 'IST',
  });

  @override
  String toString() => '$name, $state';
}

/// Authoritative directory of Indian cities covering ALL 28 States and 8 Union Territories.
class IndianCitiesData {
  static const List<IndianCity> cities = [
    // --- 28 STATES ---
    
    // 1. Andhra Pradesh
    IndianCity(id: 'visakhapatnam', name: 'Visakhapatnam', state: 'Andhra Pradesh', latitude: 17.6868, longitude: 83.2185),
    IndianCity(id: 'vijayawada', name: 'Vijayawada', state: 'Andhra Pradesh', latitude: 16.5062, longitude: 80.6480),
    IndianCity(id: 'tirupati', name: 'Tirupati', state: 'Andhra Pradesh', latitude: 13.6288, longitude: 79.4192),
    IndianCity(id: 'guntur', name: 'Guntur', state: 'Andhra Pradesh', latitude: 16.3067, longitude: 80.4365),
    IndianCity(id: 'kurnool', name: 'Kurnool', state: 'Andhra Pradesh', latitude: 15.8281, longitude: 78.0373),

    // 2. Arunachal Pradesh
    IndianCity(id: 'itanagar', name: 'Itanagar', state: 'Arunachal Pradesh', latitude: 27.0844, longitude: 93.6053),
    IndianCity(id: 'naharlagun', name: 'Naharlagun', state: 'Arunachal Pradesh', latitude: 27.1044, longitude: 93.6939),
    IndianCity(id: 'pasighat', name: 'Pasighat', state: 'Arunachal Pradesh', latitude: 28.0667, longitude: 95.3333),

    // 3. Assam
    IndianCity(id: 'guwahati', name: 'Guwahati', state: 'Assam', latitude: 26.1445, longitude: 91.7362),
    IndianCity(id: 'silchar', name: 'Silchar', state: 'Assam', latitude: 24.8170, longitude: 92.7926),
    IndianCity(id: 'dibrugarh', name: 'Dibrugarh', state: 'Assam', latitude: 27.4728, longitude: 94.9120),
    IndianCity(id: 'jorhat', name: 'Jorhat', state: 'Assam', latitude: 26.7509, longitude: 94.2037),

    // 4. Bihar
    IndianCity(id: 'patna', name: 'Patna', state: 'Bihar', latitude: 25.5941, longitude: 85.1376),
    IndianCity(id: 'gaya', name: 'Gaya', state: 'Bihar', latitude: 24.7914, longitude: 85.0002),
    IndianCity(id: 'muzaffarpur', name: 'Muzaffarpur', state: 'Bihar', latitude: 26.1209, longitude: 85.3647),
    IndianCity(id: 'bhagalpur', name: 'Bhagalpur', state: 'Bihar', latitude: 25.2425, longitude: 86.9842),

    // 5. Chhattisgarh
    IndianCity(id: 'raipur', name: 'Raipur', state: 'Chhattisgarh', latitude: 21.2514, longitude: 81.6296),
    IndianCity(id: 'bilaspur', name: 'Bilaspur', state: 'Chhattisgarh', latitude: 22.0797, longitude: 82.1409),
    IndianCity(id: 'bhilai', name: 'Bhilai', state: 'Chhattisgarh', latitude: 21.1938, longitude: 81.3509),

    // 6. Goa
    IndianCity(id: 'panaji', name: 'Panaji', state: 'Goa', latitude: 15.4909, longitude: 73.8278),
    IndianCity(id: 'margao', name: 'Margao', state: 'Goa', latitude: 15.2832, longitude: 73.9862),
    IndianCity(id: 'vasco_da_gama', name: 'Vasco da Gama', state: 'Goa', latitude: 15.3982, longitude: 73.8113),

    // 7. Gujarat
    IndianCity(id: 'ahmedabad', name: 'Ahmedabad', state: 'Gujarat', latitude: 23.0225, longitude: 72.5714),
    IndianCity(id: 'surat', name: 'Surat', state: 'Gujarat', latitude: 21.1702, longitude: 72.8311),
    IndianCity(id: 'vadodara', name: 'Vadodara', state: 'Gujarat', latitude: 22.3072, longitude: 73.1812),
    IndianCity(id: 'rajkot', name: 'Rajkot', state: 'Gujarat', latitude: 22.3039, longitude: 70.8022),
    IndianCity(id: 'dwarka', name: 'Dwarka', state: 'Gujarat', latitude: 22.2442, longitude: 68.9685),
    IndianCity(id: 'somnath', name: 'Somnath', state: 'Gujarat', latitude: 20.8880, longitude: 70.4013),

    // 8. Haryana
    IndianCity(id: 'gurugram', name: 'Gurugram', state: 'Haryana', latitude: 28.4595, longitude: 77.0266),
    IndianCity(id: 'faridabad', name: 'Faridabad', state: 'Haryana', latitude: 28.4089, longitude: 77.3178),
    IndianCity(id: 'panipat', name: 'Panipat', state: 'Haryana', latitude: 29.3909, longitude: 76.9635),
    IndianCity(id: 'kurukshetra', name: 'Kurukshetra', state: 'Haryana', latitude: 29.9695, longitude: 76.8783),

    // 9. Himachal Pradesh
    IndianCity(id: 'shimla', name: 'Shimla', state: 'Himachal Pradesh', latitude: 31.1048, longitude: 77.1734),
    IndianCity(id: 'dharamshala', name: 'Dharamshala', state: 'Himachal Pradesh', latitude: 32.2190, longitude: 76.3234),
    IndianCity(id: 'manali', name: 'Manali', state: 'Himachal Pradesh', latitude: 32.2396, longitude: 77.1887),
    IndianCity(id: 'mandi', name: 'Mandi', state: 'Himachal Pradesh', latitude: 31.7087, longitude: 76.9320),

    // 10. Jharkhand
    IndianCity(id: 'ranchi', name: 'Ranchi', state: 'Jharkhand', latitude: 23.3441, longitude: 85.3096),
    IndianCity(id: 'jamshedpur', name: 'Jamshedpur', state: 'Jharkhand', latitude: 22.8046, longitude: 86.2029),
    IndianCity(id: 'dhanbad', name: 'Dhanbad', state: 'Jharkhand', latitude: 23.7957, longitude: 86.4304),
    IndianCity(id: 'deoghar', name: 'Deoghar', state: 'Jharkhand', latitude: 24.4826, longitude: 86.7001),

    // 11. Karnataka
    IndianCity(id: 'bangalore', name: 'Bengaluru', state: 'Karnataka', latitude: 12.9716, longitude: 77.5946),
    IndianCity(id: 'mysuru', name: 'Mysuru', state: 'Karnataka', latitude: 12.2958, longitude: 76.6394),
    IndianCity(id: 'udupi', name: 'Udupi', state: 'Karnataka', latitude: 13.3409, longitude: 74.7421),
    IndianCity(id: 'mangaluru', name: 'Mangaluru', state: 'Karnataka', latitude: 12.9141, longitude: 74.8560),
    IndianCity(id: 'hubballi', name: 'Hubballi', state: 'Karnataka', latitude: 15.3647, longitude: 75.1240),

    // 12. Kerala
    IndianCity(id: 'thiruvananthapuram', name: 'Thiruvananthapuram', state: 'Kerala', latitude: 8.5241, longitude: 76.9366),
    IndianCity(id: 'kochi', name: 'Kochi', state: 'Kerala', latitude: 9.9312, longitude: 76.2673),
    IndianCity(id: 'kozhikode', name: 'Kozhikode', state: 'Kerala', latitude: 11.2588, longitude: 75.7804),
    IndianCity(id: 'thrissur', name: 'Thrissur', state: 'Kerala', latitude: 10.5276, longitude: 76.2144),
    IndianCity(id: 'guruvayur', name: 'Guruvayur', state: 'Kerala', latitude: 10.5946, longitude: 76.0407),

    // 13. Madhya Pradesh
    IndianCity(id: 'bhopal', name: 'Bhopal', state: 'Madhya Pradesh', latitude: 23.2599, longitude: 77.4126),
    IndianCity(id: 'indore', name: 'Indore', state: 'Madhya Pradesh', latitude: 22.7196, longitude: 75.8577),
    IndianCity(id: 'ujjain', name: 'Ujjain', state: 'Madhya Pradesh', latitude: 23.1765, longitude: 75.7885),
    IndianCity(id: 'gwalior', name: 'Gwalior', state: 'Madhya Pradesh', latitude: 26.2183, longitude: 78.1828),
    IndianCity(id: 'jabalpur', name: 'Jabalpur', state: 'Madhya Pradesh', latitude: 23.1815, longitude: 79.9864),

    // 14. Maharashtra
    IndianCity(id: 'mumbai', name: 'Mumbai', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777),
    IndianCity(id: 'pune', name: 'Pune', state: 'Maharashtra', latitude: 18.5204, longitude: 73.8567),
    IndianCity(id: 'nagpur', name: 'Nagpur', state: 'Maharashtra', latitude: 21.1458, longitude: 79.0882),
    IndianCity(id: 'nashik', name: 'Nashik', state: 'Maharashtra', latitude: 19.9975, longitude: 73.7898),
    IndianCity(id: 'pandharpur', name: 'Pandharpur', state: 'Maharashtra', latitude: 17.6775, longitude: 75.3277),
    IndianCity(id: 'shirdi', name: 'Shirdi', state: 'Maharashtra', latitude: 19.7645, longitude: 74.4762),

    // 15. Manipur
    IndianCity(id: 'imphal', name: 'Imphal', state: 'Manipur', latitude: 24.8170, longitude: 93.9368),
    IndianCity(id: 'churachandpur', name: 'Churachandpur', state: 'Manipur', latitude: 24.3333, longitude: 93.6667),

    // 16. Meghalaya
    IndianCity(id: 'shillong', name: 'Shillong', state: 'Meghalaya', latitude: 25.5788, longitude: 91.8933),
    IndianCity(id: 'tura', name: 'Tura', state: 'Meghalaya', latitude: 25.5144, longitude: 90.2032),

    // 17. Mizoram
    IndianCity(id: 'aizawl', name: 'Aizawl', state: 'Mizoram', latitude: 23.7271, longitude: 92.7176),
    IndianCity(id: 'lunglei', name: 'Lunglei', state: 'Mizoram', latitude: 22.8878, longitude: 92.7423),

    // 18. Nagaland
    IndianCity(id: 'kohima', name: 'Kohima', state: 'Nagaland', latitude: 25.6751, longitude: 94.1086),
    IndianCity(id: 'dimapur', name: 'Dimapur', state: 'Nagaland', latitude: 25.9096, longitude: 93.7266),

    // 19. Odisha
    IndianCity(id: 'bhubaneswar', name: 'Bhubaneswar', state: 'Odisha', latitude: 20.2961, longitude: 85.8245),
    IndianCity(id: 'puri', name: 'Puri', state: 'Odisha', latitude: 19.8135, longitude: 85.8312),
    IndianCity(id: 'cuttack', name: 'Cuttack', state: 'Odisha', latitude: 20.4625, longitude: 85.8828),
    IndianCity(id: 'rourkela', name: 'Rourkela', state: 'Odisha', latitude: 22.2604, longitude: 84.8536),

    // 20. Punjab
    IndianCity(id: 'amritsar', name: 'Amritsar', state: 'Punjab', latitude: 31.6340, longitude: 74.8723),
    IndianCity(id: 'ludhiana', name: 'Ludhiana', state: 'Punjab', latitude: 30.9010, longitude: 75.8573),
    IndianCity(id: 'jalandhar', name: 'Jalandhar', state: 'Punjab', latitude: 31.3260, longitude: 75.5762),
    IndianCity(id: 'patiala', name: 'Patiala', state: 'Punjab', latitude: 30.3398, longitude: 76.3869),

    // 21. Rajasthan
    IndianCity(id: 'jaipur', name: 'Jaipur', state: 'Rajasthan', latitude: 26.9124, longitude: 75.7873),
    IndianCity(id: 'jodhpur', name: 'Jodhpur', state: 'Rajasthan', latitude: 26.2389, longitude: 73.0243),
    IndianCity(id: 'udaipur', name: 'Udaipur', state: 'Rajasthan', latitude: 24.5854, longitude: 73.7125),
    IndianCity(id: 'kota', name: 'Kota', state: 'Rajasthan', latitude: 25.2138, longitude: 75.8648),
    IndianCity(id: 'pushkar', name: 'Pushkar', state: 'Rajasthan', latitude: 26.4897, longitude: 74.5511),

    // 22. Sikkim
    IndianCity(id: 'gangtok', name: 'Gangtok', state: 'Sikkim', latitude: 27.3389, longitude: 88.6065),
    IndianCity(id: 'namchi', name: 'Namchi', state: 'Sikkim', latitude: 27.1667, longitude: 88.3500),

    // 23. Tamil Nadu
    IndianCity(id: 'chennai', name: 'Chennai', state: 'Tamil Nadu', latitude: 13.0827, longitude: 80.2707),
    IndianCity(id: 'madurai', name: 'Madurai', state: 'Tamil Nadu', latitude: 9.9252, longitude: 78.1198),
    IndianCity(id: 'coimbatore', name: 'Coimbatore', state: 'Tamil Nadu', latitude: 11.0168, longitude: 76.9558),
    IndianCity(id: 'tiruchirappalli', name: 'Tiruchirappalli', state: 'Tamil Nadu', latitude: 10.7905, longitude: 78.7047),
    IndianCity(id: 'srirangam', name: 'Srirangam', state: 'Tamil Nadu', latitude: 10.8622, longitude: 78.6946),
    IndianCity(id: 'kanyakumari', name: 'Kanyakumari', state: 'Tamil Nadu', latitude: 8.0883, longitude: 77.5385),
    IndianCity(id: 'salem', name: 'Salem', state: 'Tamil Nadu', latitude: 11.6643, longitude: 78.1460),
    IndianCity(id: 'tirunelveli', name: 'Tirunelveli', state: 'Tamil Nadu', latitude: 8.7139, longitude: 77.7567),

    // 24. Telangana
    IndianCity(id: 'hyderabad', name: 'Hyderabad', state: 'Telangana', latitude: 17.3850, longitude: 78.4867),
    IndianCity(id: 'warangal', name: 'Warangal', state: 'Telangana', latitude: 17.9689, longitude: 79.5941),
    IndianCity(id: 'nizamabad', name: 'Nizamabad', state: 'Telangana', latitude: 18.6725, longitude: 78.0941),
    IndianCity(id: 'karimnagar', name: 'Karimnagar', state: 'Telangana', latitude: 18.4386, longitude: 79.1288),

    // 25. Tripura
    IndianCity(id: 'agartala', name: 'Agartala', state: 'Tripura', latitude: 23.8315, longitude: 91.2868),
    IndianCity(id: 'dharmanagar', name: 'Dharmanagar', state: 'Tripura', latitude: 24.3739, longitude: 92.1643),

    // 26. Uttar Pradesh
    IndianCity(id: 'lucknow', name: 'Lucknow', state: 'Uttar Pradesh', latitude: 26.8467, longitude: 80.9462),
    IndianCity(id: 'varanasi', name: 'Varanasi', state: 'Uttar Pradesh', latitude: 25.3176, longitude: 82.9739),
    IndianCity(id: 'mathura', name: 'Mathura', state: 'Uttar Pradesh', latitude: 27.4924, longitude: 77.6737),
    IndianCity(id: 'vrindavan', name: 'Vrindavan', state: 'Uttar Pradesh', latitude: 27.5806, longitude: 77.7006),
    IndianCity(id: 'ayodhya', name: 'Ayodhya', state: 'Uttar Pradesh', latitude: 26.7922, longitude: 82.1998),
    IndianCity(id: 'prayagraj', name: 'Prayagraj', state: 'Uttar Pradesh', latitude: 25.4358, longitude: 81.8463),
    IndianCity(id: 'kanpur', name: 'Kanpur', state: 'Uttar Pradesh', latitude: 26.4499, longitude: 80.3319),
    IndianCity(id: 'agra', name: 'Agra', state: 'Uttar Pradesh', latitude: 27.1767, longitude: 78.0081),

    // 27. Uttarakhand
    IndianCity(id: 'dehradun', name: 'Dehradun', state: 'Uttarakhand', latitude: 30.3165, longitude: 78.0322),
    IndianCity(id: 'haridwar', name: 'Haridwar', state: 'Uttarakhand', latitude: 29.9457, longitude: 78.1642),
    IndianCity(id: 'rishikesh', name: 'Rishikesh', state: 'Uttarakhand', latitude: 30.0869, longitude: 78.2676),
    IndianCity(id: 'badrinath', name: 'Badrinath', state: 'Uttarakhand', latitude: 30.7433, longitude: 79.4938),

    // 28. West Bengal
    IndianCity(id: 'kolkata', name: 'Kolkata', state: 'West Bengal', latitude: 22.5726, longitude: 88.3639),
    IndianCity(id: 'mayapur', name: 'Mayapur (Navadvipa)', state: 'West Bengal', latitude: 23.4233, longitude: 88.3908),
    IndianCity(id: 'siliguri', name: 'Siliguri', state: 'West Bengal', latitude: 26.7271, longitude: 88.3953),
    IndianCity(id: 'asansol', name: 'Asansol', state: 'West Bengal', latitude: 23.6739, longitude: 86.9524),

    // --- 8 UNION TERRITORIES ---

    // 1. Andaman and Nicobar Islands
    IndianCity(id: 'port_blair', name: 'Port Blair', state: 'Andaman & Nicobar Islands', isUnionTerritory: true, latitude: 11.6234, longitude: 92.7265),

    // 2. Chandigarh
    IndianCity(id: 'chandigarh', name: 'Chandigarh', state: 'Chandigarh', isUnionTerritory: true, latitude: 30.7333, longitude: 76.7794),

    // 3. Dadra and Nagar Haveli and Daman and Diu
    IndianCity(id: 'daman', name: 'Daman', state: 'Dadra & Nagar Haveli and Daman & Diu', isUnionTerritory: true, latitude: 20.3974, longitude: 72.8328),
    IndianCity(id: 'silvassa', name: 'Silvassa', state: 'Dadra & Nagar Haveli and Daman & Diu', isUnionTerritory: true, latitude: 20.2763, longitude: 73.0083),

    // 4. Delhi (NCT)
    IndianCity(id: 'delhi', name: 'New Delhi', state: 'Delhi', isUnionTerritory: true, latitude: 28.6139, longitude: 77.2090),

    // 5. Jammu and Kashmir
    IndianCity(id: 'srinagar', name: 'Srinagar', state: 'Jammu & Kashmir', isUnionTerritory: true, latitude: 34.0837, longitude: 74.7973),
    IndianCity(id: 'jammu', name: 'Jammu', state: 'Jammu & Kashmir', isUnionTerritory: true, latitude: 32.7266, longitude: 74.8570),

    // 6. Ladakh
    IndianCity(id: 'leh', name: 'Leh', state: 'Ladakh', isUnionTerritory: true, latitude: 34.1526, longitude: 77.5771),
    IndianCity(id: 'kargil', name: 'Kargil', state: 'Ladakh', isUnionTerritory: true, latitude: 34.5539, longitude: 76.1349),

    // 7. Lakshadweep
    IndianCity(id: 'kavaratti', name: 'Kavaratti', state: 'Lakshadweep', isUnionTerritory: true, latitude: 10.5669, longitude: 72.6420),

    // 8. Puducherry
    IndianCity(id: 'puducherry', name: 'Puducherry', state: 'Puducherry', isUnionTerritory: true, latitude: 11.9416, longitude: 79.8083),
  ];

  /// Get distinct sorted list of all States & Union Territories
  static List<String> getAllStates() {
    final stateSet = <String>{};
    for (final c in cities) {
      stateSet.add(c.state);
    }
    final list = stateSet.toList();
    list.sort();
    return list;
  }

  /// Get all cities for a given state
  static List<IndianCity> getCitiesForState(String state) {
    return cities.where((c) => c.state == state).toList();
  }

  /// Get city by ID
  static IndianCity? getCityById(String id) {
    for (final c in cities) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Default city (New Delhi or Chennai)
  static IndianCity get defaultCity => getCityById('delhi') ?? cities.first;

  /// Find nearest city given latitude and longitude using Haversine distance
  static IndianCity findNearestCity(double latitude, double longitude) {
    IndianCity nearest = cities.first;
    double minDistance = double.infinity;

    for (final c in cities) {
      final d = _haversineDistance(latitude, longitude, c.latitude, c.longitude);
      if (d < minDistance) {
        minDistance = d;
        nearest = c;
      }
    }
    return nearest;
  }

  /// Convenience getter for all states and UTs
  static List<String> get statesAndUTs => getAllStates();

  /// Search cities by query (matches city name or state name) with optional state filtering
  static List<IndianCity> searchCities(String query, {String? state}) {
    final q = query.trim().toLowerCase();
    return cities.where((c) {
      if (state != null && state.isNotEmpty && state != 'All' && c.state != state) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.state.toLowerCase().contains(q);
    }).toList();
  }

  /// Haversine distance in kilometers between two points
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
