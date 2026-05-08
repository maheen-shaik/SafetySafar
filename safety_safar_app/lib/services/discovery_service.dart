class Recommendation {
  final String id;
  final String name;
  final String type; // hotel, restaurant, attraction, medical
  final double latitude;
  final double longitude;
  final String address;
  final double rating;
  final String? imageUrl;
  final String? phone;

  Recommendation({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.rating,
    this.imageUrl,
    this.phone,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unnamed Place',
      type: json['type'] ?? 'general',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.0,
      imageUrl: json['image_url'],
      phone: json['phone'],
    );
  }
}

class DiscoveryService {
  static Future<List<Recommendation>> getNearby(double lat, double lng, {String? category}) async {
    // In a real app, this would call Google Places or a custom backend endpoint
    // For now, returning mock data centered around the user's location
    await Future.delayed(const Duration(seconds: 1));

    final List<Map<String, dynamic>> mockData = [
      {
        'id': '1',
        'name': 'City General Hospital',
        'type': 'medical',
        'latitude': lat + 0.005,
        'longitude': lng + 0.005,
        'address': 'Medical Square, Downtown',
        'rating': 4.5,
        'phone': '102',
      },
      {
        'id': '2',
        'name': 'The Grand Residency',
        'type': 'hotel',
        'latitude': lat - 0.008,
        'longitude': lng + 0.002,
        'address': '123 Luxury Lane',
        'rating': 4.8,
      },
      {
        'id': '3',
        'name': 'Traditional Flavors',
        'type': 'restaurant',
        'latitude': lat + 0.003,
        'longitude': lng - 0.004,
        'address': 'Foodie Street, Sector 4',
        'rating': 4.2,
      },
      {
        'id': '4',
        'name': 'Ancient Palace Grounds',
        'type': 'attraction',
        'latitude': lat + 0.015,
        'longitude': lng - 0.010,
        'address': 'Heritage Zone',
        'rating': 4.9,
      },
      {
        'id': '5',
        'name': 'Emergency Health Clinic',
        'type': 'medical',
        'latitude': lat - 0.002,
        'longitude': lng - 0.003,
        'address': 'Convenience Corner',
        'rating': 4.0,
        'phone': '911',
      },
    ];

    var filtered = mockData;
    if (category != null) {
      filtered = mockData.where((item) => item['type'] == category).toList();
    }

    return filtered.map((e) => Recommendation.fromJson(e)).toList();
  }
}
