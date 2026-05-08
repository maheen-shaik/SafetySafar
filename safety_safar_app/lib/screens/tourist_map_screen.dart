import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class TouristMapScreen extends StatefulWidget {
  final String authToken;
  final String userId;

  const TouristMapScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<TouristMapScreen> createState() => _TouristMapScreenState();
}

class _TouristMapScreenState extends State<TouristMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  bool _isLoadingLocation = true;
  bool _isAssessing = false;
  Map<String, dynamic>? _assessment;
  String? _dangerAlert;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = pos;
        _isLoadingLocation = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
      await _loadDangerZones();
      await _trackLocation();
      await _assessZone();
      // Refresh location, track, and assessment every 30 seconds
      _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        final updated = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) setState(() => _currentPosition = updated);
        await _trackLocation();
        await _assessZone();
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _loadDangerZones() async {
    if (_currentPosition == null) return;
    try {
      final uri = Uri.parse(
        '${ApiConfig.dangerZones}?latitude=${_currentPosition!.latitude}&longitude=${_currentPosition!.longitude}&radius_km=20',
      );
      final res = await http.get(uri, headers: {'Authorization': 'Bearer ${widget.authToken}'});
      if (res.statusCode == 200 && mounted) {
        final List zones = jsonDecode(res.body);
        final Set<Circle> newCircles = {};
        final Set<Marker> zoneMarkers = {};
        for (var zone in zones) {
          final lat = (zone['latitude'] as num).toDouble();
          final lng = (zone['longitude'] as num).toDouble();
          final radius = (zone['radius'] as num).toDouble();
          final level = zone['danger_level'] as String;
          final color = _zoneColor(level);

          newCircles.add(Circle(
            circleId: CircleId('zone_${zone['id']}'),
            center: LatLng(lat, lng),
            radius: radius,
            fillColor: color.withValues(alpha: 0.25),
            strokeColor: color,
            strokeWidth: 2,
          ));
          zoneMarkers.add(Marker(
            markerId: MarkerId('zone_label_${zone['id']}'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(_zoneHue(level)),
            infoWindow: InfoWindow(
              title: zone['name'] as String,
              snippet: '${level.toUpperCase()} — ${zone['zone_type']}',
            ),
          ));
        }
        setState(() {
          _circles
            ..removeWhere((c) => c.circleId.value.startsWith('zone_'))
            ..addAll(newCircles);
          _markers
            ..removeWhere((m) => m.markerId.value.startsWith('zone_label_'))
            ..addAll(zoneMarkers);
        });
      }
    } catch (e) {
      debugPrint('Zone load error: $e');
    }
  }

  Future<void> _assessZone() async {
    if (_currentPosition == null || _isAssessing) return;
    setState(() => _isAssessing = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.assessZone),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        }),
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final status = data['zone_status'] as String? ?? 'SAFE';
        setState(() {
          _assessment = data;
          if (status == 'DANGER') {
            _dangerAlert = 'DANGER: ${data['zone_description'] ?? 'You are in a high-risk zone!'}';
          } else if (status == 'RISK') {
            _dangerAlert = 'RISK: ${data['zone_description'] ?? 'You are in a risk zone.'}';
          } else {
            _dangerAlert = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Assessment error: $e');
    } finally {
      if (mounted) setState(() => _isAssessing = false);
    }
  }

  Future<void> _trackLocation() async {
    if (_currentPosition == null) return;
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.trackLocation),
        headers: {'Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'accuracy': _currentPosition!.accuracy,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final anomalies = (data['anomalies'] as List?) ?? [];
        for (final anomaly in anomalies) {
          if (!mounted) break;
          final type = anomaly['type'] as String? ?? '';
          String msg = '';
          if (type == 'danger_zone_entry') {
            msg = 'Warning: You entered ${anomaly['zone_name']} (${(anomaly['danger_level'] as String? ?? '').toUpperCase()})';
          } else if (type == 'prolonged_inactivity') {
            msg = 'Inactivity alert sent to authorities';
          } else if (type == 'danger_zone_exit') {
            msg = 'You have left ${anomaly['zone_name']}';
          }
          if (msg.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: type == 'danger_zone_exit' ? Colors.green : Colors.red.shade700,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Track location error: $e');
    }
  }

  Color _zoneColor(String level) {
    switch (level) {
      case 'critical': return Colors.red;
      case 'high':     return Colors.deepOrange;
      case 'medium':   return Colors.orange;
      case 'safe':     return Colors.green;
      default:         return Colors.yellow.shade700;
    }
  }

  double _zoneHue(String level) {
    switch (level) {
      case 'critical': return BitmapDescriptor.hueRed;
      case 'high':     return BitmapDescriptor.hueOrange;
      case 'medium':   return BitmapDescriptor.hueYellow;
      case 'safe':     return BitmapDescriptor.hueGreen;
      default:         return BitmapDescriptor.hueGreen;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'DANGER':  return Colors.red;
      case 'RISK':    return Colors.deepOrange;
      case 'CAUTION': return Colors.orange;
      default:        return const Color(0xFF2E7D32);
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'DANGER':  return Icons.dangerous_rounded;
      case 'RISK':    return Icons.warning_rounded;
      case 'CAUTION': return Icons.info_rounded;
      default:        return Icons.check_circle_rounded;
    }
  }


  @override
  Widget build(BuildContext context) {
    final pos = _currentPosition;
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: pos != null
                  ? LatLng(pos.latitude, pos.longitude)
                  : const LatLng(20.5937, 78.9629),
              zoom: pos != null ? 15 : 5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _markers,
            circles: _circles,
            onMapCreated: (c) {
              _mapController = c;
              if (pos != null) {
                c.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15));
              }
            },
          ),

          // ── Top Bar ────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                      child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0E3A7E), size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SizedBox(width: 8),
                  // Refresh button
                  GestureDetector(
                    onTap: () async {
                      await _loadDangerZones();
                      await _assessZone();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                      child: _isAssessing
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0E3A7E)))
                          : const Icon(Icons.refresh_rounded, color: Color(0xFF0E3A7E), size: 20),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Danger Alert Banner ────────────────────────────────
          if (_dangerAlert != null)
            Positioned(
              top: 80, left: 16, right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _assessment?['zone_status'] == 'DANGER' ? Colors.red : Colors.deepOrange,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_dangerAlert!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                    GestureDetector(
                      onTap: () => setState(() => _dangerAlert = null),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ]),
                ),
              ),
            ),

          // ── My Location Button ─────────────────────────────────
          Positioned(
            bottom: _assessment != null ? 230 : 100,
            right: 16,
            child: GestureDetector(
              onTap: () {
                if (pos != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                child: const Icon(Icons.my_location_rounded, color: Color(0xFF0E3A7E), size: 22),
              ),
            ),
          ),

          // ── Loading overlay ────────────────────────────────────
          if (_isLoadingLocation)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: Color(0xFF0E3A7E)),
                      SizedBox(height: 12),
                      Text('Getting your location...'),
                    ]),
                  ),
                ),
              ),
            ),

          // ── Zone Legend ────────────────────────────────────────
          Positioned(
            top: 90,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Zones', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                _legendItem(Colors.red, 'Critical'),
                _legendItem(Colors.deepOrange, 'High'),
                _legendItem(Colors.orange, 'Medium'),
                _legendItem(Colors.yellow.shade700, 'Low'),
                _legendItem(Colors.green, 'Safe'),
              ]),
            ),
          ),

          // ── Gemini Assessment Card ─────────────────────────────
          if (_assessment != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildAssessmentCard(),
            ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10)),
      ]),
    );
  }

  Widget _buildAssessmentCard() {
    final status = _assessment!['zone_status'] as String? ?? 'SAFE';
    final score = _assessment!['safety_score'] as int? ?? 100;
    final desc = _assessment!['zone_description'] as String? ?? '';
    final recs = (_assessment!['recommendations'] as List?)?.cast<String>() ?? [];
    final aiPowered = _assessment!['ai_powered'] as bool? ?? false;
    final color = _statusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // Status header
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(status), color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
              const SizedBox(width: 10),
              // Safety score bar
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Safety Score: $score/100',
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ])),
              const SizedBox(width: 8),
              if (aiPowered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF0E3A7E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome, size: 12, color: Color(0xFF0E3A7E)),
                    SizedBox(width: 4),
                    Text('AI', style: TextStyle(fontSize: 10, color: Color(0xFF0E3A7E), fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
            const SizedBox(height: 10),
            // Description
            Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            if (recs.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...recs.take(2).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.arrow_right_rounded, color: color, size: 18),
                  const SizedBox(width: 4),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
                ]),
              )),
            ],
            const SizedBox(height: 12),
            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _assessZone,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Re-assess', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
