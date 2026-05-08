import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class TouristProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String nationality;
  final bool kycVerified;
  final String? arrivalDate;
  final String? departureDate;
  final TouristLocation? lastLocation;

  TouristProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.nationality,
    required this.kycVerified,
    this.arrivalDate,
    this.departureDate,
    this.lastLocation,
  });

  String get fullName => '$firstName $lastName';

  factory TouristProfile.fromJson(Map<String, dynamic> json) {
    return TouristProfile(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      nationality: json['nationality'] ?? '',
      kycVerified: json['kyc_verified'] ?? false,
      arrivalDate: json['arrival_date'],
      departureDate: json['departure_date'],
      lastLocation: json['last_location'] != null
          ? TouristLocation.fromJson(json['last_location'])
          : null,
    );
  }
}

class TouristLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  TouristLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory TouristLocation.fromJson(Map<String, dynamic> json) {
    return TouristLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class TouristService {
  final String authToken;

  TouristService(this.authToken);

  Future<List<TouristProfile>> getAllTourists({String? kycStatus}) async {
    final queryParams = kycStatus != null ? '?kyc_status=$kycStatus' : '';
    final response = await http.get(
      Uri.parse('${ApiConfig.tourists}$queryParams'),
      headers: {
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      // Backend returns {"tourists": [...]} or just [...]
      final List<dynamic> data = (decoded is Map) ? (decoded['tourists'] ?? []) : decoded;
      return data.map((json) => TouristProfile.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load tourists: ${response.statusCode}');
    }
  }

  Future<TouristProfile> getTouristById(String id) async {
    final response = await http.get(
      Uri.parse(ApiConfig.touristProfile(id)),
      headers: {
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      return TouristProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load tourist profile');
    }
  }
}
