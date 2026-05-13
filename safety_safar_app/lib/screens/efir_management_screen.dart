import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/api_config.dart';

class EFirManagementScreen extends StatefulWidget {
  final String authToken;
  const EFirManagementScreen({super.key, required this.authToken});

  @override
  State<EFirManagementScreen> createState() => _EFirManagementScreenState();
}

class _EFirManagementScreenState extends State<EFirManagementScreen>
    with SingleTickerProviderStateMixin {
  List _firs = [];
  bool _loading = true;
  late TabController _tabCtrl;
  static const _primaryColor = Color(0xFF0E3A7E);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _fetchFirs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFirs() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.allFirs),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _firs = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List _filtered(String status) =>
      status == 'all' ? _firs : _firs.where((f) => f['status'] == status).toList();

  Future<void> _showResolveDialog(Map fir) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resolve FIR', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Incident: ${fir['incident_type']}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('Resolution Remarks:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: remarksCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter remarks or action taken...',
                filled: true,
                fillColor: const Color(0xFFF4F7F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _resolveFir(fir['id'], remarksCtrl.text.trim());
    }
  }

  Future<void> _resolveFir(String id, String remarks) async {
    try {
      final res = await http.put(
        Uri.parse(ApiConfig.resolveFir(id)),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'remarks': remarks}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FIR resolved successfully'), backgroundColor: Colors.green),
        );
        _fetchFirs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${res.body}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _filtered('pending').length;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Row(children: [
          const Text('eFIR Management', style: TextStyle(fontWeight: FontWeight.bold)),
          if (pending > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Text('$pending new', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchFirs),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'All (${_firs.length})'),
            Tab(text: 'Pending ($pending)'),
            Tab(text: 'Resolved (${_filtered('resolved').length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList('all'),
                _buildList('pending'),
                _buildList('resolved'),
              ],
            ),
    );
  }

  Widget _buildList(String status) {
    final list = _filtered(status);
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No ${status == 'all' ? '' : status} FIRs',
              style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchFirs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) => _buildFirCard(list[i]),
      ),
    );
  }

  Widget _buildFirCard(Map fir) {
    final status = fir['status'] ?? 'pending';
    final isPending = status == 'pending';
    final statusColor = isPending ? Colors.orange : (status == 'resolved' ? Colors.green : Colors.blue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPending ? Border.all(color: Colors.orange.shade200, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: _primaryColor.withValues(alpha: 0.1),
          child: Text(
            (fir['tourist_name'] ?? '?').substring(0, 1).toUpperCase(),
            style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(children: [
          Expanded(
            child: Text(fir['incident_type'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status.toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
        subtitle: Text(
          '${fir['tourist_name'] ?? 'Unknown'}  •  ${_formatDate(fir['created_at'])}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        children: [
          _row('Tourist', fir['tourist_name'] ?? ''),
          _row('Phone', fir['tourist_phone'] ?? ''),
          _row('Description', fir['description'] ?? ''),
          if (fir['address'] != null && fir['address'].toString().isNotEmpty)
            _row('Location', fir['address']),
          if (fir['latitude'] != null)
            _row('GPS', '${fir['latitude']}, ${fir['longitude']}'),
          if (fir['remarks'] != null && fir['remarks'].toString().isNotEmpty)
            _row('Remarks', fir['remarks'], highlight: true),
          if ((fir['image_filenames'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            const Text('Evidence Photos',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: (fir['image_filenames'] as List).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final filename = fir['image_filenames'][i];
                  final url = ApiConfig.firImage(fir['id'], filename);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
                        headers: {'Authorization': 'Bearer ${widget.authToken}'},
                        errorBuilder: (_, _, _) => Container(
                          width: 80, height: 80, color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image),
                        )),
                  );
                },
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showResolveDialog(fir),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Mark as Resolved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 100,
        child: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: Text(value,
            style: TextStyle(
              fontSize: 13,
              color: highlight ? Colors.green.shade700 : Colors.black87,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            )),
      ),
    ]),
  );

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
