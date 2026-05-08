import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/api_config.dart';
import 'notification_service.dart';

class AnomalyEvent {
  final String type;
  final String severity;
  final String message;
  final Map<String, dynamic> data;

  AnomalyEvent({required this.type, required this.severity, required this.message, required this.data});

  Color get color => severity == 'critical' ? Colors.red[900]! : Colors.orange[800]!;
  IconData get icon => type == 'geofence_exit' ? Icons.location_off : Icons.warning_amber_rounded;

  factory AnomalyEvent.fromJson(Map<String, dynamic> json) {
    return AnomalyEvent(
      type: json['type'] ?? 'unknown',
      severity: json['severity'] ?? 'info',
      message: json['description'] ?? 'Safety anomaly detected',
      data: Map<String, dynamic>.from(json),
    );
  }
}

class LocationTrackingService {
  final String _authToken;
  Timer? _periodicTimer;
  StreamSubscription<Position>? _positionStream;

  // Geofence Throttling State
  bool _isCurrentlyOutside = false;

  static const double safeRadiusKm = 2000.0; // Covers India
  static const double centerLat = 20.5937;
  static const double centerLng = 78.9629;

  LocationTrackingService(this._authToken);

  Future<void> startTracking(Function(String) onStatus, Function(String) onError, {Function(AnomalyEvent)? onAnomalyDetected}) async {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      onStatus('${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
      _checkGeofenceThrottled(pos, onAnomalyDetected);
    }, onError: (e) => onError(e.toString()));

    _periodicTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendLocation(onAnomalyDetected: onAnomalyDetected),
    );
  }

  void stopTracking() {
    _periodicTimer?.cancel();
    _positionStream?.cancel();
  }

  void _checkGeofenceThrottled(Position pos, Function(AnomalyEvent)? callback) {
    double dist = _calculateDistance(centerLat, centerLng, pos.latitude, pos.longitude);
    bool isOutside = dist > safeRadiusKm;

    // Only trigger if state CHANGED (prevents spamming every second)
    if (isOutside && !_isCurrentlyOutside) {
      _isCurrentlyOutside = true;
      callback?.call(AnomalyEvent(
        type: 'geofence_exit',
        severity: 'critical',
        message: 'CRITICAL: You have exited the Safe Travel Zone!',
        data: {'distance': dist}
      ));
    } else if (!isOutside && _isCurrentlyOutside) {
      _isCurrentlyOutside = false; // User returned to safe zone
    }
  }

  Future<void> _sendLocation({Function(AnomalyEvent)? onAnomalyDetected}) async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final res = await http.post(
        Uri.parse(ApiConfig.trackLocation),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_authToken'},
        body: jsonEncode({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'accuracy': pos.accuracy,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final anomalies = (data['anomalies'] as List?) ?? [];
        for (final anomaly in anomalies) {
          final type = anomaly['type'] as String? ?? '';
          final zoneName = anomaly['zone_name'] as String? ?? 'Unknown Zone';
          final level = anomaly['danger_level'] as String? ?? 'medium';
          final zoneType = anomaly['zone_type'] as String? ?? 'unsafe';

          if (type == 'danger_zone_entry') {
            // Push notification (works when app is backgrounded / screen off)
            await NotificationService.showZoneEntryAlert(
              zoneName: zoneName,
              dangerLevel: level,
              zoneType: zoneType,
            );
            // In-app callback for foreground popup
            onAnomalyDetected?.call(AnomalyEvent(
              type: type,
              severity: level == 'critical' || level == 'high' ? 'critical' : 'warning',
              message: 'You entered "$zoneName"',
              data: {
                'zone_name': zoneName,
                'danger_level': level,
                'zone_type': zoneType,
                'threat_label': zoneType.replaceAll('_', ' ').toUpperCase(),
              },
            ));
          } else if (type == 'danger_zone_exit') {
            await NotificationService.showZoneExitAlert(zoneName: zoneName);
          } else if (type == 'prolonged_inactivity') {
            onAnomalyDetected?.call(AnomalyEvent(
              type: type,
              severity: 'critical',
              message: 'Inactivity alert sent to authorities',
              data: anomaly,
            ));
          }
        }
      }
    } catch (_) {}
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 +
          c(lat1 * p) * c(lat2 * p) *
          (1 - c((lon2 - lon1) * p))/2;
    return 12742 * math.asin(math.sqrt(a));
  }

  Future<Position?> getCurrentLocation() async => await Geolocator.getCurrentPosition();
}
