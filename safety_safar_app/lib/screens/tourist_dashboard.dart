import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../digital_id_screen.dart';
import '../login_screen.dart';
import '../services/location_tracking_service.dart';
import '../services/discovery_service.dart';
import '../utils/api_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tourist_map_screen.dart';
import 'my_firs_screen.dart';
import 'weather_screen.dart';
import '../services/llm_chatbot_service.dart';

class TouristDashboard extends StatefulWidget {
  final String authToken;
  final String userId;

  const TouristDashboard({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<TouristDashboard> createState() => _TouristDashboardState();
}

class _TouristDashboardState extends State<TouristDashboard>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late LocationTrackingService _tracker;
  String _locationStatus = 'Initializing tracking...';
  bool _locationError = false;
  Map<String, dynamic>? profileData;
  bool isLoading = true;

  // Anomaly alert queue
  final List<AnomalyEvent> _anomalyQueue = [];
  bool _showingAnomaly = false;
  late AnimationController _anomalySlideCtrl;
  late Animation<Offset> _anomalySlide;

  // SOS progress
  double _sosProgress = 0.0;
  late AnimationController _sosPulseCtrl;

  // Safety Score
  int _safetyScore = 100;
  String _safetyLevel = "Excellent";
  Color _safetyColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _anomalySlideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _anomalySlide = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(CurvedAnimation(parent: _anomalySlideCtrl, curve: Curves.easeOutCubic));
    _sosPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _tracker = LocationTrackingService(widget.authToken);
    _startTracking();
    _fetchProfile();
  }

  @override
  void dispose() {
    _tracker.stopTracking();
    _anomalySlideCtrl.dispose();
    _sosPulseCtrl.dispose();
    super.dispose();
  }

  void _startTracking() {
    _tracker.startTracking(
      (status) => setState(() { _locationStatus = status; _locationError = false; }),
      (err) => setState(() { _locationStatus = err; _locationError = true; }),
      onAnomalyDetected: _handleAnomaly,
    );
  }

  void _handleAnomaly(AnomalyEvent event) {
    if (!mounted) return;
    setState(() {
      _anomalyQueue.add(event);
      if (event.severity == 'critical') { _safetyScore = (_safetyScore - 15).clamp(0, 100); }
      else if (event.severity == 'warning') { _safetyScore = (_safetyScore - 5).clamp(0, 100); }
      _updateSafetyLevel();
    });
    if (!_showingAnomaly) _showNextAnomaly();
  }

  void _updateSafetyLevel() {
    if (_safetyScore > 80) { _safetyLevel = "Excellent"; _safetyColor = Colors.green; }
    else if (_safetyScore > 50) { _safetyLevel = "Fair"; _safetyColor = Colors.orange; }
    else { _safetyLevel = "At Risk"; _safetyColor = Colors.red; }
  }

  void _showNextAnomaly() {
    if (_anomalyQueue.isEmpty) { setState(() => _showingAnomaly = false); return; }
    setState(() => _showingAnomaly = true);
    _anomalySlideCtrl.forward(from: 0);
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        _anomalySlideCtrl.reverse().then((_) {
          if (mounted) { setState(() => _anomalyQueue.removeAt(0)); _showNextAnomaly(); }
        });
      }
    });
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/me'), headers: {'Authorization': 'Bearer ${widget.authToken}'});
      if (res.statusCode == 200 && mounted) setState(() { profileData = jsonDecode(res.body); isLoading = false; });
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _handleSOS() async {
    final pos = await _tracker.getCurrentLocation();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚨 SOS Alert Sent! Authorities notified.'), backgroundColor: Colors.red));
    try {
      await http.post(Uri.parse('${ApiConfig.baseUrl}/alerts/sos'), headers: {'Authorization': 'Bearer ${widget.authToken}', 'Content-Type': 'application/json'}, body: jsonEncode({'latitude': pos?.latitude ?? 0.0, 'longitude': pos?.longitude ?? 0.0, 'message': 'Manual SOS'}));
    } catch (_) {}
  }

  void _handleLogout() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: Stack(
        children: [
          isLoading ? const Center(child: CircularProgressIndicator()) : _buildPageBody(),
          if (_showingAnomaly && _anomalyQueue.isNotEmpty) _buildAnomalyBanner(_anomalyQueue.first),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (c) => _ChatbotSheet(
            userLocation: _locationStatus,
            safetyScore: _safetyScore,
          ),
        ),
        backgroundColor: const Color(0xFF0E3A7E),
        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      _TouristNavItem(Icons.home_rounded, 'Home'),
      _TouristNavItem(Icons.qr_code_rounded, 'Digital ID'),
      _TouristNavItem(Icons.cloud_rounded, 'Weather'),
      _TouristNavItem(Icons.map_rounded, 'Safe Zones'),
      _TouristNavItem(Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.07), blurRadius: 16, offset: const Offset(0, -3))]),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final bool sel = _selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].icon, size: 24, color: sel ? const Color(0xFF0E3A7E) : Colors.grey),
                      Text(items[i].label, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.normal, color: sel ? const Color(0xFF0E3A7E) : Colors.grey)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildPageBody() {
    switch (_selectedIndex) {
      case 0: return _buildHomeTab();
      case 1: return DigitalIDScreen(userData: profileData);
      case 2: return const WeatherScreen();
      case 3: return _buildSafeZonesTab();
      case 4: return _buildProfileTab();
      default: return const SizedBox();
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildTrackingBar(),
            const SizedBox(height: 32),
            _buildProfessionalSOSButton(),
            const SizedBox(height: 32),
            _buildNearbyEssentials(),
            const SizedBox(height: 24),
            _buildStatCard("SAFETY SCORE", "$_safetyScore/100 • $_safetyLevel", Icons.verified_user, _safetyColor),
            const SizedBox(height: 16),
            _buildKYCStatusCard(),
            const SizedBox(height: 16),
            _buildItineraryCard(),
            const SizedBox(height: 16),
            _buildEmergencyCard(),
            const SizedBox(height: 16),
            _buildEFirCard(),
            const SizedBox(height: 80),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A2A5E), Color(0xFF1E40AF)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Welcome back,', style: TextStyle(color: Colors.white60, fontSize: 13)), Text(profileData?['first_name'] ?? 'Tourist', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))]),
        IconButton(onPressed: _handleLogout, icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20))),
      ]),
    );
  }

  Widget _buildTrackingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: _locationError ? Colors.red.withValues(alpha:0.06) : Colors.green.withValues(alpha:0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: _locationError ? Colors.red.withValues(alpha:0.3) : Colors.green.withValues(alpha:0.3))),
      child: Row(children: [
        Icon(_locationError ? Icons.location_off : Icons.gps_fixed, color: _locationError ? Colors.red : Colors.green, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(_locationStatus, style: TextStyle(color: _locationError ? Colors.red.shade700 : Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w700))),
        Text(_locationError ? 'ERR' : 'LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _locationError ? Colors.red : Colors.green)),
      ]),
    );
  }

  Widget _buildProfessionalSOSButton() {
    return Column(children: [
      GestureDetector(
        onLongPressStart: (_) => setState(() => _sosProgress = 1.0),
        onLongPressEnd: (_) { if (_sosProgress == 1.0) _handleSOS(); setState(() => _sosProgress = 0.0); },
        child: Stack(alignment: Alignment.center, children: [
          ScaleTransition(scale: Tween(begin: 1.0, end: 1.25).animate(_sosPulseCtrl), child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withValues(alpha:0.1)))),
          SizedBox(width: 160, height: 160, child: CircularProgressIndicator(value: _sosProgress, strokeWidth: 8, color: Colors.redAccent, backgroundColor: Colors.transparent)),
          Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFB71C1C)]), boxShadow: [BoxShadow(color: Colors.red.withValues(alpha:0.4), blurRadius: 25)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.shield_rounded, color: Colors.white, size: 42), Text('SOS', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))])),
        ]),
      ),
      const SizedBox(height: 12),
      const Text('HOLD TO SOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 1)),
    ]);
  }

  Widget _buildNearbyEssentials() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('NEARBY ESSENTIALS (20KM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1)),
      const SizedBox(height: 12),
      SizedBox(height: 100, child: ListView(scrollDirection: Axis.horizontal, children: [
        _discTile(Icons.medical_services, 'Hospitals', Colors.red, 'medical'),
        _discTile(Icons.hotel, 'Hotels', Colors.blue, 'hotel'),
        _discTile(Icons.restaurant, 'Food', Colors.orange, 'restaurant'),
        _discTile(Icons.camera_alt, 'Attractions', Colors.purple, 'attraction'),
      ])),
    ]);
  }

  Widget _discTile(IconData i, String l, Color c, String t) => GestureDetector(
    onTap: () async {
      final pos = await _tracker.getCurrentLocation();
      if (!mounted) return;
      showModalBottomSheet(context: context, backgroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (c) => _NearbyPlacesList(title: l, type: t, lat: pos?.latitude ?? 0, lng: pos?.longitude ?? 0));
    },
    child: Container(width: 90, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 28), Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))])),
  );

  Widget _buildStatCard(String title, String val, IconData icon, Color color) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEDF1F5))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)), Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))]), Icon(icon, color: color, size: 30)]));

  Widget _buildKYCStatusCard() {
    final bool ok = profileData?['kyc_verified'] ?? false;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [Icon(ok ? Icons.verified_user : Icons.pending_actions, color: ok ? Colors.green : Colors.orange, size: 32), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('IDENTITY STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)), Text(ok ? 'Verified Official' : 'Verification Pending', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))]))]));
  }

  Widget _buildItineraryCard() {
    final it = profileData?['itinerary'];
    String d = it is List ? it.join(', ') : (it is Map ? (it['destinations'] as List).join(', ') : 'Not Set');
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TRAVEL ITINERARY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0E3A7E))), const SizedBox(height: 16), Text(d, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), Text("Arrival: ${profileData?['arrival_date'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey, fontSize: 12))]));
  }

  Widget _buildEmergencyCard() => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)), child: ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(profileData?['emergency_name'] ?? 'Not Set', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(profileData?['emergency_phone'] ?? '---')));

  Widget _buildEFirCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => MyFirsScreen(authToken: widget.authToken))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.article_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('eFIR — File a Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 4),
            Text('Report theft, assault, fraud & more', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
        ]),
      ),
    );
  }

  Widget _buildSafeZonesTab() => TouristMapScreen(
        authToken: widget.authToken,
        userId: widget.userId,
      );

  Widget _buildProfileTab() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [const SizedBox(height: 40), const CircleAvatar(radius: 60, child: Icon(Icons.person, size: 60)), const SizedBox(height: 20), Text('${profileData?['first_name']} ${profileData?['last_name']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 40), ElevatedButton(onPressed: _handleLogout, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56)), child: const Text('Logout Session'))]));

  Widget _buildAnomalyBanner(AnomalyEvent event) {
    final zoneName   = event.data['zone_name']    as String? ?? '';
    final level      = event.data['danger_level'] as String? ?? event.severity;
    final threatType = event.data['threat_label'] as String? ?? event.data['zone_type']?.toString().toUpperCase() ?? '';
    final isEntry    = event.type == 'danger_zone_entry';

    Color bg;
    switch (level) {
      case 'critical': bg = const Color(0xFFB71C1C); break;
      case 'high':     bg = const Color(0xFFE65100); break;
      case 'medium':   bg = const Color(0xFFF57F17); break;
      default:         bg = const Color(0xFF1B5E20);
    }

    return SafeArea(
      child: SlideTransition(
        position: _anomalySlide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(20),
            color: bg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(isEntry ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEntry ? 'DANGER ZONE ENTERED' : 'Zone Exited',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
                          fontSize: 14, letterSpacing: 0.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _anomalySlideCtrl.reverse().then((_) {
                        if (mounted) { setState(() { _anomalyQueue.removeAt(0); }); _showNextAnomaly(); }
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ]),
                if (zoneName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(zoneName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
                if (threatType.isNotEmpty || level.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    if (threatType.isNotEmpty) _badge(threatType, Colors.white24),
                    const SizedBox(width: 8),
                    if (level.isNotEmpty) _badge('Level: ${level.toUpperCase()}', Colors.white30),
                  ]),
                ],
                const SizedBox(height: 8),
                Text(event.message,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _NearbyPlacesList extends StatelessWidget {
  final String title;
  final String type;
  final double lat;
  final double lng;

  const _NearbyPlacesList({
    required this.title,
    required this.type,
    required this.lat,
    required this.lng,
  });

  static const _primary = Color(0xFF0E3A7E);

  IconData get _icon {
    switch (type) {
      case 'medical':    return Icons.local_hospital_rounded;
      case 'hotel':      return Icons.hotel_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      default:           return Icons.camera_alt_rounded;
    }
  }

  Color get _color {
    switch (type) {
      case 'medical':    return Colors.red;
      case 'hotel':      return Colors.blue;
      case 'restaurant': return Colors.orange;
      default:           return Colors.purple;
    }
  }

  Future<void> _openMaps(double placeLat, double placeLng, String name, String placeId) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$placeLat,$placeLng'
      '&destination=${Uri.encodeComponent(name)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          Icon(_icon, color: _color, size: 22),
          const SizedBox(width: 10),
          Text('Nearby $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Recommendation>>(
          future: DiscoveryService.getNearby(lat, lng, category: type),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }
            if (snap.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load places.\nCheck internet connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600)),
              ));
            }
            final places = snap.data ?? [];
            if (places.isEmpty) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_off_rounded, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No $title found within 10 km.',
                      style: TextStyle(color: Colors.grey.shade600)),
                ]),
              ));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = places[i];
                final dist = p.distanceKm != null
                    ? p.distanceKm! < 1
                        ? '${(p.distanceKm! * 1000).round()} m'
                        : '${p.distanceKm!.toStringAsFixed(1)} km'
                    : '';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon, color: _color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (p.address.isNotEmpty)
                          Text(p.address,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                      if (dist.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(dist,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primary)),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.location_on_rounded, color: _color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        dist.isNotEmpty ? '$dist away' : 'Nearby',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _openMaps(p.latitude, p.longitude, p.name, p.placeId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(children: [
                            Icon(Icons.directions_rounded, color: Colors.white, size: 15),
                            SizedBox(width: 5),
                            Text('Directions', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ]),
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _ChatbotSheet extends StatefulWidget {
  final String userLocation;
  final int safetyScore;
  const _ChatbotSheet({this.userLocation = 'India', this.safetyScore = 100});
  @override
  State<_ChatbotSheet> createState() => _ChatbotSheetState();
}

class _ChatbotSheetState extends State<_ChatbotSheet> {
  final List<Map<String, dynamic>> _messages = [
    {'role': 'bot', 'text': 'Hello! I\'m your SafetySafar AI Assistant. Ask me anything about travel safety, local tips, or recommendations! 🌍'}
  ];
  final _ctrl = TextEditingController();
  bool _isLoading = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    if (!LLMChatbotService.isConfigured()) {
      _messages.add({'role': 'bot', 'text': '⚠️ AI service not configured.\n\n${LLMChatbotService.getSetupInstructions()}'});
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isLoading) return;
    _ctrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _scrollToBottom();
    try {
      final context = 'Location: ${widget.userLocation}\nSafety Score: ${widget.safetyScore}/100';
      final response = await LLMChatbotService.chat(userMessage: text, context: context);
      if (mounted) setState(() { _messages.add({'role': 'bot', 'text': response.isEmpty ? '⚠️ No response received. Please try again.' : response}); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _messages.add({'role': 'bot', 'text': '❌ Error: $e'}); _isLoading = false; });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            const Text('🤖 SafetySafar AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Real-time travel safety guidance powered by AI', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
        const Divider(height: 20),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) {
                return Align(alignment: Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))));
              }
              final msg = _messages[i];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF0E3A7E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(msg['text'] ?? '', style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 14, height: 1.4)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                enabled: !_isLoading,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _isLoading ? 'Waiting for response...' : 'Ask me anything...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF0E3A7E), width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _isLoading ? Colors.grey.shade400 : const Color(0xFF0E3A7E), shape: BoxShape.circle),
                child: Icon(_isLoading ? Icons.hourglass_empty : Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TouristNavItem { final IconData icon; final String label; const _TouristNavItem(this.icon, this.label); }
