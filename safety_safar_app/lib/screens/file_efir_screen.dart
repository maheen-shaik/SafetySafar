import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../utils/api_config.dart';

class FileEFirScreen extends StatefulWidget {
  final String authToken;
  const FileEFirScreen({super.key, required this.authToken});

  @override
  State<FileEFirScreen> createState() => _FileEFirScreenState();
}

class _FileEFirScreenState extends State<FileEFirScreen> {
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  String _incidentType = 'Theft';
  final List<XFile> _images = [];
  bool _isSubmitting = false;
  double? _lat, _lng;
  bool _locLoading = false;

  static const _incidentTypes = [
    'Theft', 'Assault', 'Fraud', 'Accident', 'Harassment', 'Other'
  ];

  static const _primaryColor = Color(0xFF0E3A7E);

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _locLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {}
    setState(() => _locLoading = false);
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked);
      });
    }
  }

  Future<void> _submitFir() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final req = http.MultipartRequest('POST', Uri.parse(ApiConfig.fileFir));
      req.headers['Authorization'] = 'Bearer ${widget.authToken}';
      req.fields['incident_type'] = _incidentType;
      req.fields['description'] = _descController.text.trim();
      if (_lat != null) req.fields['latitude'] = _lat.toString();
      if (_lng != null) req.fields['longitude'] = _lng.toString();
      if (_addressController.text.trim().isNotEmpty) {
        req.fields['address'] = _addressController.text.trim();
      }
      for (final img in _images) {
        req.files.add(await http.MultipartFile.fromPath('images', img.path));
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('eFIR filed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to file eFIR: ${res.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('File eFIR', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              title: 'Incident Details',
              icon: Icons.report_problem_rounded,
              children: [
                _label('Incident Type'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _incidentType,
                  decoration: _inputDecoration('Select type'),
                  items: _incidentTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _incidentType = v!),
                ),
                const SizedBox(height: 14),
                _label('Description *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: _inputDecoration('Describe what happened in detail...'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Location',
              icon: Icons.location_on_rounded,
              children: [
                _locLoading
                    ? const Row(children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Capturing location...'),
                      ])
                    : _lat != null
                        ? Row(children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            Text('${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _captureLocation,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Refresh'),
                            )
                          ])
                        : Row(children: [
                            const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                            const SizedBox(width: 6),
                            const Text('Location unavailable'),
                            const Spacer(),
                            TextButton(onPressed: _captureLocation, child: const Text('Retry')),
                          ]),
                const SizedBox(height: 10),
                _label('Address / Landmark (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  decoration: _inputDecoration('e.g. Near Charminar, Hyderabad'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Evidence Photos (optional)',
              icon: Icons.photo_camera_rounded,
              children: [
                if (_images.isNotEmpty)
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(_images[i].path),
                                width: 90, height: 90, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _images.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Add Photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: const BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitFir,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit eFIR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: _primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF4F7F9),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
