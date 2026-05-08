import 'package:flutter/material.dart';
import '../services/kyc_service.dart';
import 'kyc_review_detail_screen.dart';

class KYCPendingListScreen extends StatefulWidget {
  final String authToken;
  final String userId;

  const KYCPendingListScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<KYCPendingListScreen> createState() => _KYCPendingListScreenState();
}

class _KYCPendingListScreenState extends State<KYCPendingListScreen> {
  late KYCService _kycService;
  late Future<List<dynamic>> _pendingFuture;

  String _searchQuery = '';
  List<dynamic> _allPending = [];
  List<dynamic> _filteredPending = [];

  @override
  void initState() {
    super.initState();
    _kycService = KYCService(widget.authToken);
    _loadPending();
  }

  void _loadPending() {
    _pendingFuture = _kycService.getPendingKYC().then((pending) {
      _allPending = pending;
      _applySearch();
      return _filteredPending;
    });
  }

  void _applySearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredPending = _allPending;
      } else {
        final q = _searchQuery.toLowerCase();
        _filteredPending = _allPending.where((t) {
          final fn = t['first_name']?.toString().toLowerCase() ?? '';
          final ln = t['last_name']?.toString().toLowerCase() ?? '';
          final em = t['email']?.toString().toLowerCase() ?? '';
          return '$fn $ln'.contains(q) || em.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _pendingFuture,
          builder: (ctx, snapshot) {
            return Column(
              children: [
                _buildHeader(),
                if (snapshot.connectionState != ConnectionState.waiting)
                  _buildSearchBar(),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF0E3A7E)))
                      : snapshot.hasError
                          ? _buildError(snapshot.error.toString())
                          : _buildList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFF57C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KYC Verification',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const Text('Approval Queue',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('${_allPending.length} application${_allPending.length != 1 ? 's' : ''} pending',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_user_rounded,
                color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha:0.04), blurRadius: 10)
                ],
                border: Border.all(color: const Color(0xFFEDF1F5)),
              ),
              child: TextField(
                onChanged: (v) {
                  _searchQuery = v;
                  _applySearch();
                },
                decoration: const InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Color(0xFF0E3A7E)),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _loadPending,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEDF1F5)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 20, color: Color(0xFF0E3A7E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_filteredPending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha:0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.done_all_rounded,
                  size: 50, color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text('Queue Empty!',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF1E293B))),
            const Text('All KYC applications are processed',
                style: TextStyle(
                    color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadPending(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _filteredPending.length,
        itemBuilder: (ctx, i) => _buildKYCCard(_filteredPending[i]),
      ),
    );
  }

  Widget _buildKYCCard(dynamic tourist) {
    final String firstName = tourist['first_name'] ?? 'Unknown';
    final String lastName = tourist['last_name'] ?? '';
    final String email = tourist['email'] ?? '';
    final String phone = tourist['phone'] ?? '';
    final String nationality = tourist['nationality'] ?? '';
    final String userId = tourist['id'] ?? '';
    final String? rejectionReason = tourist['kyc_rejection_reason'];
    final bool isRejected =
        rejectionReason != null && rejectionReason.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KYCReviewDetailScreen(
              authToken: widget.authToken,
              userId: userId,
              firstName: firstName,
              lastName: lastName,
              email: email,
              phone: phone,
              nationality: nationality,
              onApprovedOrRejected: () => setState(() => _loadPending()),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRejected
                ? Colors.red.withValues(alpha:0.25)
                : Colors.orange.withValues(alpha:0.2),
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x04000000),
                blurRadius: 10,
                offset: Offset(0, 4))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Initial avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                          (isRejected ? Colors.red : Colors.orange).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        firstName.isNotEmpty
                            ? firstName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: isRejected ? Colors.red : Colors.orange,
                            fontSize: 20,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$firstName $lastName',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF1E293B))),
                        Text(nationality,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isRejected
                          ? Colors.red.withValues(alpha:0.08)
                          : Colors.orange.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            isRejected
                                ? Icons.cancel_rounded
                                : Icons.pending_rounded,
                            size: 12,
                            color: isRejected ? Colors.red : Colors.orange),
                        const SizedBox(width: 4),
                        Text(isRejected ? 'Rejected' : 'Pending',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    isRejected ? Colors.red : Colors.orange)),
                      ],
                    ),
                  ),
                ],
              ),

              if (isRejected) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha:0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha:0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rejectionReason,
                          style: const TextStyle(
                              color: Color(0xFF7F1D1D),
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              _infoRow(Icons.email_rounded, email),
              const SizedBox(height: 5),
              _infoRow(Icons.phone_rounded, phone),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.touch_app_rounded,
                        size: 14, color: Color(0xFF0E3A7E)),
                    SizedBox(width: 8),
                    Text('Tap to review documents & approve/reject',
                        style: TextStyle(
                            color: Color(0xFF0E3A7E),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 56, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Failed to load KYC records',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _loadPending,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E3A7E),
                  foregroundColor: Colors.white),
              child: const Text('Retry')),
        ],
      ),
    );
  }
}
