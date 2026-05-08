import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../utils/api_config.dart';

class SOSAlertsScreen extends StatefulWidget {
  final String authToken;
  const SOSAlertsScreen({super.key, required this.authToken});

  @override
  State<SOSAlertsScreen> createState() => _SOSAlertsScreenState();
}

class _SOSAlertsScreenState extends State<SOSAlertsScreen>
    with SingleTickerProviderStateMixin {
  List _alerts = [];
  bool _isLoading = true;
  String _filter = 'all';
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _fetchAlerts();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAlerts() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse(ApiConfig.alerts),
          headers: {'Authorization': 'Bearer ${widget.authToken}'});
      if (res.statusCode == 200 && mounted) {
        final dynamic d = jsonDecode(res.body);
        setState(() {
          _alerts = (d is List) ? d : (d['alerts'] ?? d['data'] ?? []);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List get _filtered {
    if (_filter == 'all') return _alerts;
    return _alerts.where((a) => a['status'] == _filter).toList();
  }

  int get _activeCount =>
      _alerts.where((a) => a['status'] == 'active').length;

  Future<void> _resolve(dynamic id) async {
    final ctrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.green),
          SizedBox(width: 8),
          Text('Resolve Alert',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Resolution note (optional):',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'E.g. Tourist found safe...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: const Color(0xFFF8F9FB),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await http.post(Uri.parse(ApiConfig.resolveAlert(id)),
          headers: {
            'Authorization': 'Bearer ${widget.authToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'note': ctrl.text}));
      _fetchAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Alert resolved'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildFilterRow(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0E3A7E)))
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _fetchAlerts,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildCard(_filtered[i]),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  // ── BLUE HEADER ─────────────────────────────────────────────
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
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('SOS Alerts',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
            const Text('Notification Center',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('${_alerts.length} total  •  $_activeCount active',
                style:
                    const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        // Active pulse badge or quiet bell
        if (_activeCount > 0)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red
                    .withValues(alpha:0.2 + _pulseCtrl.value * 0.2),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.red.withValues(alpha:0.6), width: 2),
              ),
              child: Text('$_activeCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.notifications_none_rounded,
                color: Colors.white, size: 22),
          ),
      ]),
    );
  }

  // ── FILTER ROW ──────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(children: [
        _chip('All', 'all', Icons.list_rounded),
        const SizedBox(width: 8),
        _chip('Active', 'active', Icons.emergency_rounded),
        const SizedBox(width: 8),
        _chip('Resolved', 'resolved', Icons.check_circle_rounded),
        const Spacer(),
        GestureDetector(
          onTap: _fetchAlerts,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Icon(Icons.refresh_rounded,
                size: 18, color: Color(0xFF0E3A7E)),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    final bool sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF0E3A7E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: sel
                  ? const Color(0xFF0E3A7E)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 13,
              color: sel ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      sel ? Colors.white : const Color(0xFF64748B))),
        ]),
      ),
    );
  }

  // ── ALERT CARD ──────────────────────────────────────────────
  Widget _buildCard(dynamic alert) {
    final bool active = alert['status'] == 'active';
    final String name = alert['name'] ?? 'Unknown Tourist';
    final String phone = alert['phone'] ?? '';
    final String createdAt = alert['created_at'] ?? '';
    final String lat = alert['latitude']?.toString() ?? '';
    final String lng = alert['longitude']?.toString() ?? '';
    final String location = (lat.isNotEmpty && lng.isNotEmpty)
        ? '${double.tryParse(lat)?.toStringAsFixed(4) ?? lat}, ${double.tryParse(lng)?.toStringAsFixed(4) ?? lng}'
        : 'Location unavailable';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? Colors.red.withValues(alpha:0.28)
              : Colors.green.withValues(alpha:0.18),
          width: active ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: active
                  ? Colors.red.withValues(alpha:0.05)
                  : Colors.black.withValues(alpha:0.03),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        // ── top row ──
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: active
                    ? Colors.red.withValues(alpha:0.1)
                    : Colors.green.withValues(alpha:0.1),
                child: Icon(
                    active
                        ? Icons.emergency_rounded
                        : Icons.check_circle_rounded,
                    color: active ? Colors.red : Colors.green,
                    size: 24),
              ),
              if (active)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) => Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.red
                            .withValues(alpha: 0.5 + _pulseCtrl.value * 0.5),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF1E293B))),
                Text(phone,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: active
                    ? Colors.red.withValues(alpha:0.08)
                    : Colors.green.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                active ? '🔴 ACTIVE' : '✅ DONE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.red : Colors.green,
                    letterSpacing: 0.4),
              ),
            ),
          ]),
        ),

        // ── location row ──
        Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
              color: const Color(0xFFF4F7F9),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.location_on_rounded,
                size: 13, color: Color(0xFF0E3A7E)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(location,
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Courier',
                        color: Color(0xFF334155)))),
            Text(_formatRelativeTime(createdAt),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF94A3B8))),
          ]),
        ),

        // ── action buttons ──
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: phone.isNotEmpty
                    ? () => launchUrl(Uri.parse('tel:$phone'))
                    : null,
                icon: const Icon(Icons.call_rounded, size: 15),
                label: const Text('Call',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0E3A7E),
                  side: const BorderSide(color: Color(0xFF0E3A7E)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resolve(alert['id']),
                  icon: const Icon(Icons.check_rounded, size: 15),
                  label: const Text('Resolve',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── EMPTY STATE ─────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
              color: Colors.green.withValues(alpha:0.08),
              shape: BoxShape.circle),
          child:
              const Icon(Icons.shield_rounded, size: 56, color: Colors.green),
        ),
        const SizedBox(height: 18),
        const Text('All Clear!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        Text(
          _filter == 'all'
              ? 'No SOS alerts at this time'
              : 'No $_filter alerts',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetchAlerts,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E3A7E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  String _formatRelativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}
