import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tourists_list_screen.dart';
import 'kyc_pending_list_screen.dart';
import 'live_alerts_map_screen.dart';
import 'sos_alerts_screen.dart';
import 'authority_settings_screen.dart';
import 'efir_management_screen.dart';
import 'danger_zone_management_screen.dart';
import '../login_screen.dart';
import '../utils/api_config.dart';

class AuthorityDashboard extends StatefulWidget {
  final String authToken;
  final String userId;

  const AuthorityDashboard({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<AuthorityDashboard> createState() => _AuthorityDashboardState();
}

class _AuthorityDashboardState extends State<AuthorityDashboard>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int totalTourists = 0;
  int pendingKyc = 0;
  int activeAlertsCount = 0;
  List alertsList = [];
  bool isLoading = true;
  Map<String, dynamic>? profileData;
  late AnimationController _fadeController;

  // ── nav items ──────────────────────────────────────────────────
  static const _navItems = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.people_alt_rounded, 'Tourists'),
    _NavItem(Icons.verified_user_rounded, 'KYC'),
    _NavItem(Icons.emergency_rounded, 'SOS'),
    _NavItem(Icons.article_rounded, 'eFIR'),
    _NavItem(Icons.map_rounded, 'Tracking'),
    _NavItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..forward();
    _refreshAll();
    _startPolling();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return false;
      _refreshAll();
      return true;
    });
  }

  Future<void> _refreshAll() async {
    try {
      final statsRes = await http.get(
        Uri.parse(ApiConfig.dashboardStats),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      final alertsRes = await http.get(
        Uri.parse(ApiConfig.alerts),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (profileData == null) {
        final meRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/me'),
          headers: {'Authorization': 'Bearer ${widget.authToken}'},
        );
        if (meRes.statusCode == 200 && mounted) {
          setState(() => profileData = jsonDecode(meRes.body));
        }
      }
      if (statsRes.statusCode == 200 &&
          alertsRes.statusCode == 200 &&
          mounted) {
        final stats = jsonDecode(statsRes.body);
        final dynamic ad = jsonDecode(alertsRes.body);
        setState(() {
          totalTourists = stats['total_tourists'] ?? 0;
          pendingKyc = stats['pending_kyc'] ?? 0;
          alertsList = (ad is List) ? ad : (ad['alerts'] ?? []);
          activeAlertsCount =
              alertsList.where((a) => a['status'] == 'active').length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content:
            const Text('Are you sure you want to end your monitoring session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (r) => false,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: FadeTransition(opacity: _fadeController, child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── BOTTOM NAV — icon-pill style, NOT congested ───────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha:0.07),
              blurRadius: 16,
              offset: const Offset(0, -3))
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final bool selected = _selectedIndex == i;
              final item = _navItems[i];
              final int badge = (i == 3) ? activeAlertsCount : 0;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF0E3A7E)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.icon,
                              size: 22,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          if (badge > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle),
                                child: Center(
                                  child: Text('$badge',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: selected
                              ? const Color(0xFF0E3A7E)
                              : const Color(0xFF94A3B8),
                        ),
                        child: Text(item.label),
                      ),
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

  // ── BODY SWITCHER ──────────────────────────────────────────────
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return TouristsListScreen(
            authToken: widget.authToken, userId: widget.userId);
      case 2:
        return KYCPendingListScreen(
            authToken: widget.authToken, userId: widget.userId);
      case 3:
        return SOSAlertsScreen(authToken: widget.authToken);
      case 4:
        return EFirManagementScreen(authToken: widget.authToken);
      case 5:
        return LiveAlertsMapScreen(
            authToken: widget.authToken, alerts: alertsList);
      case 6:
        return AuthoritySettingsScreen(
          authToken: widget.authToken,
          userId: widget.userId,
          profileData: profileData,
        );
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  // ── DASHBOARD TAB ──────────────────────────────────────────────
  Widget _buildDashboardTab() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(
          child: isLoading
              ? const SizedBox(
                  height: 300,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF0E3A7E))))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSOSBanner(),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      _sectionTitle('QUICK ACTIONS'),
                      const SizedBox(height: 12),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _sectionTitle('LIVE INCIDENT FEED'),
                      const SizedBox(height: 12),
                      _buildAlertFeed(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ── SLIVER APP BAR ─────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    final String name =
        '${profileData?['first_name'] ?? ''} ${profileData?['last_name'] ?? 'Officer'}'
            .trim();
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0E3A7E),
      automaticallyImplyLeading: false,
      title: const Text('Safety Command Center',
          style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800)),
      actions: [
        if (activeAlertsCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.red, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.emergency_rounded,
                  color: Colors.white, size: 13),
              const SizedBox(width: 4),
              Text('$activeAlertsCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
        IconButton(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout_rounded,
              color: Colors.white, size: 22),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A2A5E), Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha:0.2),
                    child: Text(
                      (name.isNotEmpty) ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Safety Command',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 11)),
                        Text(
                          name.isEmpty ? 'Authority Officer' : name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── SOS BANNER ────────────────────────────────────────────────
  Widget _buildSOSBanner() {
    if (activeAlertsCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha:0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha:0.12),
                shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded,
                color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('System Status: All Clear',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.green,
                    fontSize: 14)),
            Text('No active SOS alerts',
                style: TextStyle(color: Colors.green, fontSize: 11)),
          ]),
        ]),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 3),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.red.withValues(alpha:0.3),
                blurRadius: 12,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          const Icon(Icons.emergency_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('⚠ ACTIVE SOS SIGNALS',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              Text(
                  '$activeAlertsCount Alert${activeAlertsCount > 1 ? 's' : ''} Need Attention',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white70, size: 22),
        ]),
      ),
    );
  }

  // ── STATS GRID ────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    return Column(children: [
      Row(children: [
        Expanded(
            child: _statCard('TOURISTS', '$totalTourists',
                Icons.people_alt_rounded, const Color(0xFF0E3A7E), 1)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard('PENDING KYC', '$pendingKyc',
                Icons.pending_actions_rounded, Colors.orange, 2)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _statCard('SOS ACTIVE', '$activeAlertsCount',
                Icons.emergency_rounded, Colors.red, 3)),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard(
                'TRACKING', 'LIVE', Icons.radar_rounded, Colors.teal, 4,
                isText: true)),
      ]),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      int navIndex,
      {bool isText = false}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = navIndex),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDF1F5)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 17),
            ),
            Icon(Icons.arrow_outward_rounded,
                color: Colors.grey.shade300, size: 14),
          ]),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: isText ? 18 : 24,
                  fontWeight: FontWeight.w900,
                  color: isText ? color : const Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8)),
        ]),
      ),
    );
  }

  // ── QUICK ACTIONS ─────────────────────────────────────────────
  Widget _buildQuickActions() {
    final tabActions = [
      ('Tourists', Icons.people_alt_rounded, const Color(0xFF0E3A7E), 1),
      ('KYC', Icons.verified_user_rounded, Colors.orange, 2),
      ('Live Map', Icons.map_rounded, Colors.teal, 5),
      ('Settings', Icons.settings_rounded, Colors.blueGrey, 6),
    ];
    return Column(children: [
      // Danger Zones — full-width featured card
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DangerZoneManagementScreen(authToken: widget.authToken),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.withAlpha(25), shape: BoxShape.circle),
              child: const Icon(Icons.add_location_alt_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Manage Danger Zones', style: TextStyle(fontWeight: FontWeight.w800,
                  fontFamily: 'Outfit', color: Colors.red, fontSize: 14)),
              SizedBox(height: 2),
              Text('Mark & remove risk zones — tourists get alerts on entry',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'Outfit')),
            ])),
            const Icon(Icons.chevron_right_rounded, color: Colors.red),
          ]),
        ),
      ),
      // Other tab-switch actions
      Row(
        children: tabActions.map((a) {
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = a.$4),
              child: Container(
                margin: tabActions.indexOf(a) < tabActions.length - 1
                    ? const EdgeInsets.only(right: 10)
                    : EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEDF1F5)),
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: a.$3.withAlpha(25), shape: BoxShape.circle),
                    child: Icon(a.$2, color: a.$3, size: 20),
                  ),
                  const SizedBox(height: 7),
                  Text(a.$1, style: const TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  // ── SECTION TITLE ─────────────────────────────────────────────
  Widget _sectionTitle(String t) => Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: const Color(0xFF0E3A7E),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(t,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 1.1)),
      ]);

  // ── ALERT FEED ────────────────────────────────────────────────
  Widget _buildAlertFeed() {
    if (alertsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDF1F5)),
        ),
        child: const Center(
          child: Text('No incidents recorded',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
      );
    }
    return Column(
      children: alertsList.take(5).map((a) {
        final bool active = a['status'] == 'active';
        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = 3),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? Colors.red.withValues(alpha:0.22)
                    : const Color(0xFFEDF1F5),
              ),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: active
                    ? Colors.red.withValues(alpha:0.1)
                    : Colors.green.withValues(alpha:0.1),
                child: Icon(
                    active
                        ? Icons.emergency_rounded
                        : Icons.check_circle_rounded,
                    color: active ? Colors.red : Colors.green,
                    size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(a['name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF1E293B))),
                    Text(a['phone'] ?? '',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                  ])),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.red.withValues(alpha:0.08)
                      : Colors.green.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(active ? 'ACTIVE' : 'RESOLVED',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: active ? Colors.red : Colors.green,
                        letterSpacing: 0.5)),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
