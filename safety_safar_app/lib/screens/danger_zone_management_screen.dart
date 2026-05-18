import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../utils/api_config.dart';

class DangerZoneManagementScreen extends StatefulWidget {
  final String authToken;
  const DangerZoneManagementScreen({super.key, required this.authToken});

  @override
  State<DangerZoneManagementScreen> createState() =>
      _DangerZoneManagementScreenState();
}

class _DangerZoneManagementScreenState
    extends State<DangerZoneManagementScreen> {
  static const _primary = Color(0xFF0E3A7E);
  static const _bg = Color(0xFFF4F7F9);

  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Form fields
  final _nameCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  double _radiusM = 300;
  String _dangerLevel = 'medium';
  String _zoneType = 'unsafe';

  final _formKey = GlobalKey<FormState>();
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _descCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.dangerZones),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (res.statusCode == 200 && mounted) {
        final list = jsonDecode(res.body) as List;
        setState(() => _zones = List<Map<String, dynamic>>.from(list));
      }
    } catch (e) {
      _snack('Failed to load zones: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition();
      _latCtrl.text = pos.latitude.toStringAsFixed(6);
      _lngCtrl.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      _snack('Could not get location: $e', isError: true);
    }
  }

  Future<void> _addZone() async {
    if (!_formKey.currentState!.validate()) return;
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      _snack('Invalid coordinates', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.addDangerZone),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': _nameCtrl.text.trim(),
          'latitude': lat,
          'longitude': lng,
          'radius': _radiusM,
          'danger_level': _dangerLevel,
          'zone_type': _zoneType,
          'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'reason': _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 200 && mounted) {
        _snack('Zone added — tourists will be alerted on entry');
        _nameCtrl.clear();
        _latCtrl.clear();
        _lngCtrl.clear();
        _descCtrl.clear();
        _reasonCtrl.clear();
        setState(() { _showForm = false; _radiusM = 300; _dangerLevel = 'medium'; _zoneType = 'unsafe'; });
        _loadZones();
      } else {
        final msg = jsonDecode(res.body)['detail'] ?? 'Failed to add zone';
        _snack(msg.toString(), isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteZone(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate Zone'),
        content: Text('Remove "$name" from active danger zones?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await http.delete(
        Uri.parse(ApiConfig.deleteDangerZone(id)),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (res.statusCode == 200 && mounted) {
        _snack('Zone deactivated');
        _loadZones();
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        title: const Text('Danger Zone Management',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadZones,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Add zone toggle ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => setState(() => _showForm = !_showForm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFF1B5BA8)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _primary.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  Icon(_showForm ? Icons.close_rounded : Icons.add_location_alt_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(_showForm ? 'Cancel' : 'Mark New Danger Zone',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                          fontFamily: 'Outfit', fontSize: 15)),
                ]),
              ),
            ),
          ),

          // ── Add zone form ────────────────────────────────────────
          if (_showForm) _buildAddForm(),

          // ── Zone list ────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : _zones.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _zones.length,
                        itemBuilder: (_, i) => _buildZoneCard(_zones[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withAlpha(40)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Zone Details', style: TextStyle(fontWeight: FontWeight.w800,
              color: _primary, fontFamily: 'Outfit', fontSize: 15)),
          const SizedBox(height: 14),

          // Name
          _field(_nameCtrl, 'Zone Name *', Icons.label_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 10),

          // Lat/Lng row
          Row(children: [
            Expanded(child: _field(_latCtrl, 'Latitude *', Icons.location_on_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid';
                  return null;
                })),
            const SizedBox(width: 10),
            Expanded(child: _field(_lngCtrl, 'Longitude *', Icons.location_on_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid';
                  return null;
                })),
          ]),
          const SizedBox(height: 8),

          // Use current location
          TextButton.icon(
            onPressed: _useCurrentLocation,
            icon: const Icon(Icons.my_location_rounded, size: 16),
            label: const Text('Use my current location', style: TextStyle(fontFamily: 'Outfit')),
            style: TextButton.styleFrom(foregroundColor: _primary, padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 10),

          // Radius slider
          Row(children: [
            const Icon(Icons.radar_rounded, color: _primary, size: 18),
            const SizedBox(width: 8),
            Text('Radius: ${_radiusM.round()} m',
                style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Outfit', color: _primary)),
          ]),
          Slider(
            value: _radiusM,
            min: 100, max: 2000,
            divisions: 38,
            activeColor: _primary,
            onChanged: (v) => setState(() => _radiusM = v),
          ),
          const SizedBox(height: 10),

          // Danger level + Zone type row
          Row(children: [
            Expanded(child: _dropdown('Danger Level', _dangerLevel,
                {'low': '🟡 Low', 'medium': '🟠 Medium', 'high': '🔴 High', 'critical': '🚨 Critical'},
                (v) => setState(() => _dangerLevel = v!))),
            const SizedBox(width: 10),
            Expanded(child: _dropdown('Zone Type', _zoneType,
                {'unsafe': 'Unsafe', 'restricted': 'Restricted', 'construction': 'Construction', 'industrial': 'Industrial'},
                (v) => setState(() => _zoneType = v!))),
          ]),
          const SizedBox(height: 10),

          // Description & Reason (optional)
          _field(_descCtrl, 'Description (optional)', Icons.info_outline_rounded),
          const SizedBox(height: 10),
          _field(_reasonCtrl, 'Reason (optional)', Icons.report_outlined),
          const SizedBox(height: 16),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _addZone,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_location_alt_rounded, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Add Danger Zone',
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Outfit'),
      validator: validator,
      inputFormatters: keyboardType == const TextInputType.numberWithOptions(decimal: true, signed: true)
          ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'Outfit', fontSize: 13),
        prefixIcon: Icon(icon, color: _primary, size: 18),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: _primary, width: 2)),
        filled: true, fillColor: Colors.white,
      ),
    );
  }

  Widget _dropdown(String label, String value, Map<String, String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: _primary, width: 2)),
        filled: true, fillColor: Colors.white,
      ),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final level = zone['danger_level'] as String? ?? 'medium';
    final color = _levelColor(level);
    final radius = (zone['radius'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // Level indicator
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
          child: Center(child: Icon(_levelIcon(level), color: color, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(zone['name'] as String? ?? 'Unknown Zone',
              style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit', color: _primary)),
          const SizedBox(height: 3),
          Text('${(zone['latitude'] as num?)?.toStringAsFixed(4)}, ${(zone['longitude'] as num?)?.toStringAsFixed(4)}  •  ${radius}m radius',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: 'Outfit')),
          const SizedBox(height: 4),
          Row(children: [
            _pill(level.toUpperCase(), color),
            const SizedBox(width: 6),
            _pill((zone['zone_type'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
                Colors.blueGrey),
          ]),
        ])),
        IconButton(
          onPressed: () => _deleteZone(zone['id'] as String, zone['name'] as String? ?? ''),
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
          tooltip: 'Remove zone',
        ),
      ]),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
          color: color, fontFamily: 'Outfit')),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.location_off_rounded, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 14),
        const Text('No danger zones configured',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, color: _primary, fontSize: 16)),
        const SizedBox(height: 6),
        Text('Tap "Mark New Danger Zone" above to add one.',
            style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[500], fontSize: 13)),
      ]),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'critical': return Colors.red;
      case 'high':     return Colors.deepOrange;
      case 'medium':   return Colors.orange;
      case 'low':      return Colors.amber.shade700;
      default:         return Colors.green;
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'critical': return Icons.dangerous_rounded;
      case 'high':     return Icons.warning_rounded;
      case 'medium':   return Icons.info_rounded;
      default:         return Icons.check_circle_outline_rounded;
    }
  }
}
