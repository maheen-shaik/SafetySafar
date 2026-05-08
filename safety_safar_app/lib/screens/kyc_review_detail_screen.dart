import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/kyc_service.dart';

class KYCReviewDetailScreen extends StatefulWidget {
  final String authToken;
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String nationality;
  final VoidCallback onApprovedOrRejected;

  const KYCReviewDetailScreen({
    super.key,
    required this.authToken,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.nationality,
    required this.onApprovedOrRejected,
  });

  @override
  State<KYCReviewDetailScreen> createState() => _KYCReviewDetailScreenState();
}

class _KYCReviewDetailScreenState extends State<KYCReviewDetailScreen> {
  late KYCService _kycService;
  late Future<List<KYCDocument>> _documentsFuture;

  bool _isSubmitting = false;
  String? _selectedDocType;
  Uint8List? _documentImage;
  bool _showFullscreenImage = false;

  @override
  void initState() {
    super.initState();
    _kycService = KYCService(widget.authToken);
    _documentsFuture = _kycService.getDocuments(widget.userId);
  }

  void _downloadAndDisplayDocument(String docType) async {
    try {
      final imageData = await _kycService.downloadDocument(widget.userId, docType);
      setState(() {
        _documentImage = Uint8List.fromList(imageData);
        _selectedDocType = docType;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading document: $e')),
        );
      }
    }
  }

  void _showApproveDialog() {
    showDialog(
      context: context,
      builder: (context) => ApproveKYCDialog(
        onApprove: (notes) async {
          setState(() => _isSubmitting = true);
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          try {
            await _kycService.approvKYC(widget.userId, notes);
            if (mounted) {
              nav.pop(); // Close dialog
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('✓ KYC Approved Successfully'),
                  backgroundColor: Color(0xFF2E7D32),
                  duration: Duration(seconds: 2),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                widget.onApprovedOrRejected();
                nav.pop();
              }
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
      ),
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => RejectKYCDialog(
        onReject: (reason) async {
          setState(() => _isSubmitting = true);
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          try {
            await _kycService.rejectKYC(widget.userId, reason);
            if (mounted) {
              nav.pop(); // Close dialog
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('✓ KYC Rejected'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                widget.onApprovedOrRejected();
                nav.pop();
              }
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          } finally {
            if (mounted) setState(() => _isSubmitting = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A2A5E), Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('KYC Review',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: _showFullscreenImage && _documentImage != null
          ? _buildFullscreenImage()
          : _buildReviewContent(),
    );
  }

  Widget _buildFullscreenImage() {
    return GestureDetector(
      onTap: () => setState(() => _showFullscreenImage = false),
      child: Container(
        color: Colors.black,
        child: Center(
          child: Stack(
            children: [
              Image.memory(_documentImage!),
              Positioned(
                top: 40,
                right: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha:0.3),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() => _showFullscreenImage = false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildDocumentsSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: const Color(0xFFEDF1F5)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E3A7E).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    widget.firstName[0].toUpperCase(),
                    style: const TextStyle(color: Color(0xFF0E3A7E), fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.firstName} ${widget.lastName}',
                      style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.nationality,
                      style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.email_rounded, 'Email Address', widget.email),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone_rounded, 'Phone Number', widget.phone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: const Color(0xFF0E3A7E)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 11, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("KYC DOCUMENTS", style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 16),
        FutureBuilder<List<KYCDocument>>(
          future: _documentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF0E3A7E)));
            }
            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha:0.05), borderRadius: BorderRadius.circular(12)),
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 13)),
              );
            }

            final documents = snapshot.data ?? [];
            return Column(
              children: documents.map((doc) {
                final fileType = doc.fileType;
                final isSelected = _selectedDocType == fileType;

                return GestureDetector(
                  onTap: () => _downloadAndDisplayDocument(fileType),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFF0E3A7E) : const Color(0xFFEDF1F5), width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(fileType == "id" ? Icons.badge_rounded : Icons.camera_alt_rounded, color: const Color(0xFF0E3A7E)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(fileType == "id" ? "National ID Document" : "Live Profile Photo",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                        ),
                        if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (_documentImage != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => setState(() => _showFullscreenImage = true),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Image.memory(_documentImage!, width: double.infinity, height: 250, fit: BoxFit.cover),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.black.withValues(alpha:0.5),
                    child: const Text("Tap to view full document", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _showApproveDialog,
            icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_rounded),
            label: Text(_isSubmitting ? "Processing..." : "Approve Tourist KYC", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _showRejectDialog,
            icon: const Icon(Icons.cancel_rounded),
            label: const Text("Reject Application", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ],
    );
  }
}

class ApproveKYCDialog extends StatefulWidget {
  final Function(String?) onApprove;
  const ApproveKYCDialog({super.key, required this.onApprove});
  @override
  State<ApproveKYCDialog> createState() => _ApproveKYCDialogState();
}

class _ApproveKYCDialogState extends State<ApproveKYCDialog> {
  final _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Confirm Approval"),
      content: TextField(
        controller: _controller,
        maxLines: 2,
        decoration: const InputDecoration(hintText: "Add optional verification notes...", border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () => widget.onApprove(_controller.text), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white), child: const Text("Approve")),
      ],
    );
  }
}

class RejectKYCDialog extends StatefulWidget {
  final Function(String) onReject;
  const RejectKYCDialog({super.key, required this.onReject});
  @override
  State<RejectKYCDialog> createState() => _RejectKYCDialogState();
}

class _RejectKYCDialogState extends State<RejectKYCDialog> {
  final _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Reject Application", style: TextStyle(color: Colors.red)),
      content: TextField(
        controller: _controller,
        maxLines: 2,
        decoration: const InputDecoration(hintText: "Enter rejection reason (Required)", border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () {
          if (_controller.text.trim().isEmpty) return;
          widget.onReject(_controller.text);
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Confirm Reject")),
      ],
    );
  }
}
