import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class Recommendation {
  final String id;
  final String placeId;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final String address;
  final double rating;
  final int userRatingsTotal;
  final bool openNow;
  final double? distanceKm;

  Recommendation({
    required this.id,
    required this.placeId,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.rating,
    this.userRatingsTotal = 0,
    this.openNow = true,
    this.distanceKm,
  });
}

class DiscoveryService {
  static const String _apiKey = 'be388b6f742c4e39b6258ace7940eba1';
  static const String _baseUrl = 'https://api.geoapify.com/v2/places';

  static Future<List<Recommendation>> getNearby(
    double lat,
    double lng, {
    String? category,
    int radiusMeters = 5000,
  }) async {
    final categories = _geoapifyCategories(category);

    // Geoapify circle filter uses lon,lat order
    final url = Uri.parse(
      '$_baseUrl'
      '?categories=$categories'
      '&filter=circle:$lng,$lat,$radiusMeters'
      '&bias=proximity:$lng,$lat'
      '&limit=20'
      '&apiKey=$_apiKey',
    );

    debugPrint('[Places] Fetching $category near ($lat, $lng)');

    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

      debugPrint('[Places] STATUS: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];

        final results = features
            .map((f) => _parseFeature(f, lat, lng, category ?? 'general'))
            .where((r) => r != null)
            .cast<Recommendation>()
            .toList();

        debugPrint('[Places] ✅ Found ${results.length} places');
        return results;
      } else {
        debugPrint('[Places] ❌ Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[Places] Error: $e');
    }
    return [];
  }

  static String _geoapifyCategories(String? category) {
    switch (category) {
      case 'medical':
        return 'healthcare.hospital,healthcare.clinic_or_praxis,healthcare.pharmacy';
      case 'hotel':
        return 'accommodation.hotel,accommodation.hostel,accommodation.guest_house';
      case 'restaurant':
        return 'catering.restaurant,catering.fast_food,catering.cafe';
      case 'attraction':
        return 'tourism.attraction,tourism.sights,entertainment.museum';
      default:
        return 'healthcare.hospital';
    }
  }

  static Recommendation? _parseFeature(
      dynamic f, double userLat, double userLng, String category) {
    try {
      final props = f['properties'] as Map<String, dynamic>? ?? {};

      final name = (props['name'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      // Geoapify GeoJSON: coordinates are [lon, lat]
      final coords = f['geometry']?['coordinates'] as List<dynamic>?;
      double? lat;
      double? lng;
      if (coords != null && coords.length >= 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      } else {
        lat = (props['lat'] as num?)?.toDouble();
        lng = (props['lon'] as num?)?.toDouble();
      }
      if (lat == null || lng == null) return null;

      final address = props['address_line2'] as String? ??
          props['formatted'] as String? ?? '';

      final distMeters = (props['distance'] as num?)?.toDouble();
      final distKm = distMeters != null
          ? distMeters / 1000
          : _haversineKm(userLat, userLng, lat, lng);

      return Recommendation(
        id: props['place_id'] as String? ?? '',
        placeId: '',
        name: name,
        type: category,
        latitude: lat,
        longitude: lng,
        address: address,
        rating: 0,
        distanceKm: distKm,
      );
    } catch (e) {
      debugPrint('[Places] Parse error: $e');
      return null;
    }
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}
