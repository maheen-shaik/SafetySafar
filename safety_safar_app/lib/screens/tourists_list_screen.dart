import 'package:flutter/material.dart';
import '../services/tourist_service.dart';

class TouristsListScreen extends StatefulWidget {
  final String authToken;
  final String userId;

  const TouristsListScreen({
    super.key,
    required this.authToken,
    required this.userId,
  });

  @override
  State<TouristsListScreen> createState() => _TouristsListScreenState();
}

class _TouristsListScreenState extends State<TouristsListScreen> {
  late TouristService _touristService;
  late Future<List<TouristProfile>> _touristsFuture;

  String _searchQuery = '';
  String _kycFilter = 'all';
  List<TouristProfile> _allTourists = [];
  List<TouristProfile> _filteredTourists = [];

  @override
  void initState() {
    super.initState();
    _touristService = TouristService(widget.authToken);
    _loadTourists();
  }

  void _loadTourists() {
    _touristsFuture = _touristService
        .getAllTourists(kycStatus: _kycFilter != 'all' ? _kycFilter : null)
        .then((tourists) {
      _allTourists = tourists;
      _applySearch();
      return _filteredTourists;
    });
  }

  void _applySearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredTourists = _allTourists;
      } else {
        final query = _searchQuery.toLowerCase();
        _filteredTourists = _allTourists.where((t) {
          return t.fullName.toLowerCase().contains(query) ||
              t.email.toLowerCase().contains(query) ||
              t.phone.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: SafeArea(
        child: FutureBuilder<List<TouristProfile>>(
          future: _touristsFuture,
          builder: (context, snapshot) {
            return Column(
              children: [
                _buildHeader(),
                _buildSearchAndFilter(),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? _buildLoading()
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
          colors: [Color(0xFF0A2D6B), Color(0xFF1E40AF)],
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
                const Text('Registered Tourists',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
                const Text('Profile Directory',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('${_allTourists.length} tourists enrolled',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        children: [
          // Search bar
          Container(
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
                hintText: 'Search by name, email, or phone...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                prefixIcon:
                    Icon(Icons.search_rounded, color: Color(0xFF0E3A7E)),
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter row
          Row(
            children: [
              _filterChip('All', 'all'),
              const SizedBox(width: 8),
              _filterChip('✓ Verified', 'verified'),
              const SizedBox(width: 8),
              _filterChip('⟳ Pending', 'pending'),
              const Spacer(),
              GestureDetector(
                onTap: _loadTourists,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEDF1F5)),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      size: 18, color: Color(0xFF0E3A7E)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final bool s = _kycFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _kycFilter = value);
        _loadTourists();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: s ? const Color(0xFF0E3A7E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: s ? const Color(0xFF0E3A7E) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: s ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }

  Widget _buildList() {
    if (_filteredTourists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 64, color: Colors.grey.withValues(alpha:0.3)),
            const SizedBox(height: 16),
            const Text('No tourists found',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1E293B))),
            const Text('Try adjusting filters',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadTourists(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _filteredTourists.length,
        itemBuilder: (ctx, i) => _buildCard(_filteredTourists[i]),
      ),
    );
  }

  Widget _buildCard(TouristProfile tourist) {
    final bool verified = tourist.kycVerified;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDF1F5)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E3A7E).withValues(alpha:0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      tourist.firstName.isNotEmpty
                          ? tourist.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF0E3A7E),
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
                      Text(tourist.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF1E293B))),
                      Text(tourist.nationality,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: verified
                        ? Colors.green.withValues(alpha:0.1)
                        : Colors.orange.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          verified
                              ? Icons.verified_rounded
                              : Icons.pending_rounded,
                          size: 12,
                          color: verified ? Colors.green : Colors.orange),
                      const SizedBox(width: 4),
                      Text(verified ? 'Verified' : 'Pending',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color:
                                  verified ? Colors.green : Colors.orange)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.email_rounded, tourist.email),
            const SizedBox(height: 6),
            _infoRow(Icons.phone_rounded, tourist.phone),
            if (tourist.lastLocation != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 13, color: Color(0xFF0E3A7E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tourist.lastLocation!.latitude.toStringAsFixed(5)}, ${tourist.lastLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Courier',
                            color: Color(0xFF334155)),
                      ),
                    ),
                    Text(_formatTime(tourist.lastLocation!.timestamp),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ],
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
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF475569)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0E3A7E)));
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 56, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Failed to load tourists',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(error,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _loadTourists,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E3A7E),
                  foregroundColor: Colors.white),
              child: const Text('Retry')),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
