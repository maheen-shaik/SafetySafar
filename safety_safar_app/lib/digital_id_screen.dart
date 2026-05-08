import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DigitalIDScreen extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const DigitalIDScreen({super.key, this.userData});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E3A7E),
        elevation: 0,
        centerTitle: true,
        title: const Text("OFFICIAL DIGITAL ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 🆔 PREMIUM ID CARD
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0E3A7E).withValues(alpha:0.12), blurRadius: 30, offset: const Offset(0, 15))
                ],
              ),
              child: Column(
                children: [
                  // Card Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF0E3A7E), Color(0xFF1E40AF)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("SAFETY SAFAR • INDIA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.security_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Profile & QR Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("FULL NAME"),
                                  Text("${userData?['first_name'] ?? 'Tourist'} ${userData?['last_name'] ?? ''}",
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                                  const SizedBox(height: 16),
                                  _buildLabel("NATIONALITY"),
                                  Text(userData?['nationality'] ?? "Verified International",
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade100, width: 2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: QrImageView(
                                data: userData?['id'] ?? "SafetySafar-ID-UNVERIFIED",
                                version: QrVersions.auto,
                                size: 90.0,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0E3A7E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // ID Details Grid
                        Row(
                          children: [
                            Expanded(child: _buildMiniDetail("DOCUMENT", userData?['document_type'] ?? "Passport")),
                            Expanded(child: _buildMiniDetail("EXPIRES", "30 Days")),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Status Badge
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.verified_rounded, color: Color(0xFF2E7D32), size: 18),
                              SizedBox(width: 8),
                              Text("VERIFIED BY AUTHORITY", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 📜 SECURITY INFO
            _buildInfoSection("Blockchain Security", "Your identity is encrypted and stored on a private ledger for tamper-proof verification."),
            const SizedBox(height: 16),
            _buildInfoSection("Usage Guide", "Present this QR code at airport check-posts, hotels, and tourist entry points for rapid entry."),

            const SizedBox(height: 40),

            // 🔘 ACTION BUTTON
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E3A7E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: const Text("CLOSE DIGITAL ID", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1));

  Widget _buildMiniDetail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildLabel(label),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
    ],
  );

  Widget _buildInfoSection(String title, String body) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.info_outline_rounded, color: Color(0xFF0E3A7E), size: 20),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4)),
          ],
        ),
      ),
    ],
  );
}
