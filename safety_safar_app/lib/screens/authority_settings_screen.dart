import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../login_screen.dart';

class AuthoritySettingsScreen extends StatefulWidget {
  final String authToken;
  final String userId;
  final Map<String, dynamic>? profileData;

  const AuthoritySettingsScreen({
    super.key,
    required this.authToken,
    required this.userId,
    this.profileData,
  });

  @override
  State<AuthoritySettingsScreen> createState() =>
      _AuthoritySettingsScreenState();
}

class _AuthoritySettingsScreenState extends State<AuthoritySettingsScreen> {
  // Notification toggles
  bool _sosNotifications = true;
  bool _kycNotifications = true;
  bool _locationAlerts = true;
  bool _systemUpdates = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Tracking/monitoring settings
  bool _autoRefresh = true;
  int _refreshInterval = 10; // seconds

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text('Are you sure you want to end your secure session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('ACCOUNT'),
                    _buildAccountCard(),
                    const SizedBox(height: 20),

                    _sectionLabel('NOTIFICATIONS'),
                    _buildNotificationsCard(),
                    const SizedBox(height: 20),

                    _sectionLabel('ALERT SOUNDS'),
                    _buildSoundsCard(),
                    const SizedBox(height: 20),

                    _sectionLabel('MONITORING'),
                    _buildMonitoringCard(),
                    const SizedBox(height: 20),

                    _sectionLabel('SYSTEM'),
                    _buildSystemCard(),
                    const SizedBox(height: 20),

                    _buildLogoutButton(),
                    const SizedBox(height: 20),
                    _buildVersionInfo(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2A5E), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Authority Settings',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 0.5)),
              Text('Preferences & Configuration',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 1.4),
      ),
    );
  }

  Widget _buildAccountCard() {
    final name =
        '${widget.profileData?['first_name'] ?? ''} ${widget.profileData?['last_name'] ?? 'Authority'}'
            .trim();
    final email = widget.profileData?['email'] ?? 'authority@safetysafar.in';
    final phone = widget.profileData?['phone'] ?? 'N/A';

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          // Profile mini-card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0E3A7E), Color(0xFF1E40AF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'Authority Officer' : name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF1E293B))),
                      Text(email,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ACTIVE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.green,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _settingRow(Icons.phone_outlined, 'Phone Number', phone),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _settingRow(Icons.shield_outlined, 'Access Level',
              'National Authority'),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _settingRow(Icons.verified_user_outlined, 'Role',
              'Safety Command Officer'),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _toggleRow(
            Icons.emergency_rounded,
            'SOS Alert Notifications',
            'Get notified on every SOS trigger',
            Colors.red,
            _sosNotifications,
            (v) => setState(() => _sosNotifications = v),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _toggleRow(
            Icons.verified_user_rounded,
            'KYC Review Notifications',
            'New KYC applications from tourists',
            Colors.orange,
            _kycNotifications,
            (v) => setState(() => _kycNotifications = v),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _toggleRow(
            Icons.location_on_rounded,
            'Location Breach Alerts',
            'Tourists entering danger zones',
            Colors.deepOrange,
            _locationAlerts,
            (v) => setState(() => _locationAlerts = v),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _toggleRow(
            Icons.system_update_rounded,
            'System Updates',
            'Backend & configuration updates',
            Colors.blueGrey,
            _systemUpdates,
            (v) => setState(() => _systemUpdates = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundsCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _toggleRow(
            Icons.volume_up_rounded,
            'Alert Sounds',
            'Play audio on incoming SOS',
            const Color(0xFF0E3A7E),
            _soundEnabled,
            (v) => setState(() => _soundEnabled = v),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _toggleRow(
            Icons.vibration_rounded,
            'Vibration',
            'Vibrate on high-priority alerts',
            const Color(0xFF0E3A7E),
            _vibrationEnabled,
            (v) => setState(() => _vibrationEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _toggleRow(
            Icons.autorenew_rounded,
            'Auto-Refresh Dashboard',
            'Automatically poll for new alerts',
            Colors.teal,
            _autoRefresh,
            (v) => setState(() => _autoRefresh = v),
          ),
          if (_autoRefresh) ...[
            const Divider(height: 1, color: Color(0xFFEDF1F5)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timer_rounded,
                            color: Colors.teal, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Refresh Interval',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B))),
                            Text('Every $_refreshInterval seconds',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.teal,
                      thumbColor: Colors.teal,
                      inactiveTrackColor: Colors.teal.withValues(alpha:0.2),
                      overlayColor: Colors.teal.withValues(alpha:0.1),
                    ),
                    child: Slider(
                      value: _refreshInterval.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '$_refreshInterval s',
                      onChanged: (v) =>
                          setState(() => _refreshInterval = v.toInt()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _settingActionRow(
            Icons.security_rounded,
            'Security Policy',
            'Data encryption & session management',
            Colors.indigo,
            () => _showInfoDialog('Security Policy',
                'All data is encrypted using AES-256. Sessions expire after 24 hours of inactivity.'),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _settingActionRow(
            Icons.help_outline_rounded,
            'Help & Support',
            'Contact the Safety Safar support team',
            Colors.blue,
            () => _showInfoDialog('Help & Support',
                'For technical support, contact: support@safetysafar.gov.in\nHelpline: 1800-XXX-XXXX'),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _settingActionRow(
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            'Review data usage and privacy terms',
            Colors.purple,
            () => _showInfoDialog('Privacy Policy',
                'Safety Safar collects tourist location data solely for safety monitoring. All data is retained for 90 days.'),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F5)),
          _settingActionRow(
            Icons.bug_report_outlined,
            'Report an Issue',
            'Send feedback to the development team',
            Colors.orange,
            () => _showInfoDialog('Report Issue',
                'To report a bug or issue, please email:\nbug-report@safetysafar.gov.in'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _handleLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha:0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 22),
            const SizedBox(width: 10),
            Text(
              'Logout Secure Session',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade700,
                  letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDF1F5)),
            ),
            child: const Text(
              'Safety Safar Authority  v2.0.0  •  Build 2026',
              style: TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8), letterSpacing: 0.3),
            ),
          ),
          const SizedBox(height: 8),
          const Text('© 2026 Safety Safar. Government of India.',
              style: TextStyle(fontSize: 10, color: Color(0xFFB0BEC5))),
        ],
      ),
    );
  }

  // ── Reusable sub-widgets ─────────────────────────────────────────
  Widget _toggleRow(IconData icon, String title, String subtitle, Color color,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E293B))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: const Color(0xFF0E3A7E),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _settingRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF64748B))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _settingActionRow(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFFB0BEC5)),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEDF1F5)),
      boxShadow: const [
        BoxShadow(
            color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4))
      ],
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E3A7E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }
}
