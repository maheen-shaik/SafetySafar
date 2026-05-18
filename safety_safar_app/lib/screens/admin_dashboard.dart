import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'admin_authority_management_screen.dart';
import '../login_screen.dart';
import '../utils/api_config.dart';

class AdminDashboard extends StatefulWidget {
  final String authToken;
  final String userId;

  const AdminDashboard({super.key, required this.authToken, required this.userId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool isLoading = true;
  Map<String, dynamic>? profileData;
  late AnimationController _fadeController;

  static const Color _primaryColor = Color(0xFF0E3A7E);
  static const Color _secondaryColor = Color(0xFFFF7A00);
  static const Color _backgroundColor = Color(0xFFF4F7F9);

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.admin_panel_settings_outlined, 'Manage'),
    _NavItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();
    _loadAdminProfile();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/me'),
          headers: {'Authorization': 'Bearer ${widget.authToken}'});
      if (res.statusCode == 200 && mounted) {
        setState(() { profileData = jsonDecode(res.body); isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Outfit')),
        content: const Text('Are you sure you want to logout?', style: TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', color: _primaryColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false),
            child: const Text('Logout', style: TextStyle(fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: FadeTransition(opacity: _fadeController, child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 16, offset: const Offset(0, -3))]),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final bool selected = _selectedIndex == i;
              final item = _navItems[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected ? _primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, size: 22,
                            color: selected ? Colors.white : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected ? _primaryColor : const Color(0xFF94A3B8),
                          fontFamily: 'Outfit',
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

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardTab();
      case 1: return AdminAuthorityManagementScreen(authToken: widget.authToken);
      case 2: return _buildSettingsTab();
      default: return const Center(child: Text('Coming Soon'));
    }
  }

  Widget _buildDashboardTab() {
    final String name = '${profileData?['first_name'] ?? ''} ${profileData?['last_name'] ?? 'Admin'}'.trim();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 140, floating: false, pinned: true,
          elevation: 0, backgroundColor: _primaryColor,
          automaticallyImplyLeading: false,
          title: const Text('Admin Dashboard',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Outfit')),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [_primaryColor, Color(0xFF1B5BA8)])),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Welcome back, $name',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
                      const SizedBox(height: 4),
                      Text('System Administrator',
                          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13, fontFamily: 'Outfit')),
                    ]),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: GestureDetector(
                  onTap: _handleLogout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(200), borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [
                      Icon(Icons.logout, size: 16, color: _primaryColor),
                      SizedBox(width: 4),
                      Text('Logout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor, fontFamily: 'Outfit')),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: isLoading
              ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: _primaryColor)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [_primaryColor, Color(0xFF1B5BA8)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: _primaryColor.withAlpha(30), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: Colors.white.withAlpha(200), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.admin_panel_settings_outlined, color: _primaryColor, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Role', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Outfit')),
                            Text(profileData?['role'] ?? 'admin',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
                          ])),
                        ]),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white30, height: 0),
                        const SizedBox(height: 16),
                        Text(profileData?['email'] ?? 'N/A',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Outfit')),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    const Text('QUICK ACTIONS',
                        style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w700,
                            letterSpacing: 0.5, fontFamily: 'Outfit')),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Manage Authorities',
                      subtitle: 'Approve or reject authority registrations',
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                  ]),
                ),
        ),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: _secondaryColor.withAlpha(30), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _secondaryColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _primaryColor, fontFamily: 'Outfit')),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'Outfit')),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Column(children: [
        AppBar(
          title: const Text('Settings',
              style: TextStyle(color: _primaryColor, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Outfit')),
          backgroundColor: Colors.white, elevation: 0, leading: const SizedBox(),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Account',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryColor, letterSpacing: 0.5, fontFamily: 'Outfit')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
              child: Row(children: [
                const Icon(Icons.email_outlined, color: _primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Email', style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Outfit')),
                  Text(profileData?['email'] ?? 'N/A',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                ])),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('Session',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryColor, letterSpacing: 0.5, fontFamily: 'Outfit')),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _handleLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha(100)),
                ),
                child: const Row(children: [
                  Icon(Icons.logout, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red, fontFamily: 'Outfit')),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
