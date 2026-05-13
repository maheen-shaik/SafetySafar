import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/weather_service.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  static const _primary = Color(0xFF0E3A7E);
  static const _bg = Color(0xFFF4F7F9);

  WeatherData? _weatherData;
  bool _isLoading = true;
  String? _errorMessage;
  double _latitude = 0.0;
  double _longitude = 0.0;
  late DateTime _lastUpdated;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    _fetchLocationAndWeather();
  }

  Future<void> _fetchLocationAndWeather() async {
    try {
      setState(() => _isLoading = true);

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions denied. Using default location.';
          _latitude = 20.5937;
          _longitude = 78.9629;
          _isLoading = false;
        });
        _loadWeather();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => Position(
          latitude: 20.5937,
          longitude: 78.9629,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      _loadWeather();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWeather() async {
    try {
      final data = await WeatherService.fetchWeather(
        latitude: _latitude,
        longitude: _longitude,
      );
      setState(() {
        _weatherData = data;
        _isLoading = false;
        _errorMessage = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text('Weather & Safety', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchLocationAndWeather,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _errorMessage != null && _weatherData == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text(_errorMessage!, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetchLocationAndWeather,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    ),
  );

  Widget _buildContent() {
    final weather = _weatherData!;
    final weatherCode = int.tryParse(weather.weatherCode) ?? 0;
    final desc = WeatherService.getWeatherDescription(weatherCode);
    final emoji = WeatherService.getWeatherEmoji(weatherCode);

    return RefreshIndicator(
      onRefresh: _fetchLocationAndWeather,
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Error banner (location only, weather loaded)
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorMessage!,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
              ]),
            ),

          // Main weather card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A2A5E), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(
                color: const Color(0xFF0E3A7E).withValues(alpha: 0.35),
                blurRadius: 20, offset: const Offset(0, 8),
              )],
            ),
            child: Column(children: [
              Text('${_latitude.toStringAsFixed(2)}°, ${_longitude.toStringAsFixed(2)}°',
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 8),
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 4),
              Text('${weather.temperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900)),
              Text(desc.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(LucideIcons.wind, color: Colors.white60, size: 15),
                const SizedBox(width: 4),
                Text('${weather.windSpeed.toStringAsFixed(1)} km/h',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 20),
                const Icon(LucideIcons.clock, color: Colors.white60, size: 15),
                const SizedBox(width: 4),
                Text('Updated ${DateFormat('hh:mm a').format(_lastUpdated)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // Hazard alert card
          _buildHazardCard(weather),

          const SizedBox(height: 16),

          // Metrics row
          Row(children: [
            _metricCard(LucideIcons.thermometer, 'Temperature',
                '${weather.temperature.toStringAsFixed(1)}°C', Colors.deepOrange),
            const SizedBox(width: 12),
            _metricCard(LucideIcons.wind, 'Wind Speed',
                '${weather.windSpeed.toStringAsFixed(1)} km/h', Colors.teal),
          ]),

          const SizedBox(height: 12),

          Row(children: [
            _metricCard(LucideIcons.cloud, 'Condition', desc, _primary),
            const SizedBox(width: 12),
            _metricCard(LucideIcons.clock, 'Last Updated',
                DateFormat('hh:mm a').format(_lastUpdated), Colors.purple),
          ]),

          const SizedBox(height: 16),

          // Safety recommendations
          _buildSafetyCard(weather),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildHazardCard(WeatherData weather) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: weather.hazardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: weather.hazardColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04), blurRadius: 8,
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: weather.hazardColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_hazardIcon(weather.hazardLevel),
                color: weather.hazardColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hazard Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            const SizedBox(height: 2),
            Text(weather.hazardMessage,
                style: TextStyle(fontSize: 13, color: weather.hazardColor, fontWeight: FontWeight.w600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: weather.hazardColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(weather.hazardLevel,
                style: TextStyle(color: weather.hazardColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: weather.hazardColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_hazardRecommendation(weather.hazardLevel),
              style: TextStyle(color: weather.hazardColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _metricCard(IconData icon, String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    ),
  );

  Widget _buildSafetyCard(WeatherData weather) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.health_and_safety_rounded, color: _primary, size: 20),
        SizedBox(width: 8),
        Text('Safety Recommendations',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
      ]),
      const SizedBox(height: 14),
      _tipRow('Stay hydrated', 'Drink water regularly while travelling.'),
      const SizedBox(height: 8),
      _tipRow('Seek shelter if needed', 'Move to safe areas during hazardous weather.'),
      const SizedBox(height: 8),
      _tipRow('Monitor alerts', 'Pull down to refresh for the latest conditions.'),
    ]),
  );

  Widget _tipRow(String title, String desc) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.check_circle_rounded, color: Color(0xFF0E3A7E), size: 16),
      const SizedBox(width: 8),
      Expanded(child: RichText(text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        children: [
          TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: desc),
        ],
      ))),
    ],
  );

  IconData _hazardIcon(String level) {
    switch (level) {
      case 'CRITICAL': return LucideIcons.alertTriangle;
      case 'HIGH':     return LucideIcons.alertCircle;
      case 'MODERATE': return LucideIcons.info;
      default:         return LucideIcons.checkCircle;
    }
  }

  String _hazardRecommendation(String level) {
    switch (level) {
      case 'CRITICAL': return '🚨 Avoid outdoor activities. Seek shelter immediately.';
      case 'HIGH':     return '⚠️ Limit outdoor exposure. Wear protective gear.';
      case 'MODERATE': return '⚡ Take precautions and stay alert.';
      default:         return '✓ All clear! Enjoy your activities safely.';
    }
  }
}
