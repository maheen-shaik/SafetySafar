import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/api_config.dart';
import 'file_efir_screen.dart';

class MyFirsScreen extends StatefulWidget {
  final String authToken;
  const MyFirsScreen({super.key, required this.authToken});

  @override
  State<MyFirsScreen> createState() => _MyFirsScreenState();
}

class _MyFirsScreenState extends State<MyFirsScreen> {
  List _firs = [];
  bool _loading = true;
  static const _primaryColor = Color(0xFF0E3A7E);

  @override
  void initState() {
    super.initState();
    _fetchFirs();
  }

  Future<void> _fetchFirs() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.myFirs),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _firs = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved': return Colors.green;
      case 'in_progress': return Colors.orange;
      default: return Colors.red;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'resolved': return Icons.check_circle_rounded;
      case 'in_progress': return Icons.hourglass_top_rounded;
      default: return Icons.pending_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'resolved': return 'Resolved';
      case 'in_progress': return 'In Progress';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('My eFIRs', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchFirs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final filed = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => FileEFirScreen(authToken: widget.authToken)));
          if (filed == true) _fetchFirs();
        },
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('File New', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _firs.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _fetchFirs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _firs.length,
                    itemBuilder: (_, i) => _buildFirCard(_firs[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.folder_open_rounded, size: 72, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No eFIRs filed yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        const SizedBox(height: 8),
        Text('Tap + to file a new report', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      ],
    ),
  );

  Widget _buildFirCard(Map fir) {
    final status = fir['status'] ?? 'pending';
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_statusIcon(status), color: color, size: 22),
        ),
        title: Text(fir['incident_type'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(
          _formatDate(fir['created_at']),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_statusLabel(status),
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        children: [
          _infoRow('Description', fir['description'] ?? ''),
          if (fir['address'] != null && fir['address'].isNotEmpty)
            _infoRow('Location', fir['address']),
          if (fir['latitude'] != null)
            _infoRow('GPS', '${fir['latitude']}, ${fir['longitude']}'),
          if (fir['remarks'] != null && fir['remarks'].isNotEmpty) ...[
            const Divider(height: 16),
            _infoRow('Authority Remarks', fir['remarks'], highlight: true),
          ],
          if (fir['resolved_at'] != null)
            _infoRow('Resolved On', _formatDate(fir['resolved_at'])),
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
                    child: Image.network(url,
                        width: 80, height: 80, fit: BoxFit.cover,
                        headers: {'Authorization': 'Bearer ${widget.authToken}'},
                        errorBuilder: (_, _, _) => Container(
                          width: 80, height: 80, color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image),
                        )),
                  );
                },
              ),
            )
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                fontSize: 13,
                color: highlight ? const Color(0xFF0E3A7E) : Colors.black87,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
      ],
    ),
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
