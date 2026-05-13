import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class WeatherData {
  final double temperature;
  final double windSpeed;
  final String weatherCode;
  final String lastUpdated;
  final String hazardLevel;
  final String hazardMessage;
  final Color hazardColor;

  WeatherData({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.lastUpdated,
    required this.hazardLevel,
    required this.hazardMessage,
    required this.hazardColor,
  });
}

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch weather data from Open-Meteo API
  /// Returns [WeatherData] with temperature, wind speed, and weather conditions
  static Future<WeatherData> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final String url =
          '$_baseUrl?latitude=$latitude&longitude=$longitude&current_weather=true&timezone=auto';

      debugPrint('[Weather] Fetching weather data for ($latitude, $longitude)');

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Weather API request timed out');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // Extract current weather data
        final currentWeather = json['current_weather'] ?? {};
        final temperature = (currentWeather['temperature'] as num?)?.toDouble() ?? 0.0;
        final windSpeed = (currentWeather['windspeed'] as num?)?.toDouble() ?? 0.0;
        final weatherCode = (currentWeather['weathercode'] as num?)?.toInt() ?? 0;

        debugPrint('[Weather] ✓ Weather fetched: $temperature°C, Wind: ${windSpeed}km/h');

        // Determine hazard level and message
        final hazardInfo = _checkHazard(temperature, windSpeed);

        return WeatherData(
          temperature: temperature,
          windSpeed: windSpeed,
          weatherCode: weatherCode.toString(),
          lastUpdated: DateTime.now().toString(),
          hazardLevel: hazardInfo['level'] as String,
          hazardMessage: hazardInfo['message'] as String,
          hazardColor: hazardInfo['color'] as Color,
        );
      } else {
        throw Exception('Failed to load weather: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('[Weather] ✗ Network error: $e');
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      debugPrint('[Weather] ✗ Error: $e');
      throw Exception('Failed to fetch weather: $e');
    }
  }

  /// Check hazard level based on weather conditions
  static Map<String, dynamic> _checkHazard(double temperature, double windSpeed) {
    // Critical hazards (Red)
    if (temperature > 42 || windSpeed > 30) {
      return {
        'level': 'CRITICAL',
        'message': temperature > 42
            ? '🔥 Extreme Heat Alert: ${temperature.toStringAsFixed(1)}°C'
            : '🌪️ Severe Storm Alert: ${windSpeed.toStringAsFixed(1)} km/h',
        'color': const Color(0xFFF44336), // Red
      };
    }

    // High hazards (Orange/Yellow)
    if (temperature > 38 || windSpeed > 20) {
      return {
        'level': 'HIGH',
        'message': temperature > 38
            ? '🌡️ Heat Alert: ${temperature.toStringAsFixed(1)}°C'
            : '💨 Storm Alert: ${windSpeed.toStringAsFixed(1)} km/h',
        'color': const Color(0xFFFF9800), // Orange
      };
    }

    // Moderate hazards (Yellow)
    if (temperature > 35 || windSpeed > 15) {
      return {
        'level': 'MODERATE',
        'message': 'Warm weather & moderate winds detected',
        'color': const Color(0xFFFFC107), // Yellow
      };
    }

    // Safe conditions (Green)
    return {
      'level': 'SAFE',
      'message': '✓ Weather conditions are safe',
      'color': const Color(0xFF4CAF50), // Green
    };
  }

  /// Get weather description from weather code (WMO codes)
  static String getWeatherDescription(int weatherCode) {
    switch (weatherCode) {
      case 0:
        return 'Clear Sky';
      case 1:
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Light Rain';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Heavy Rain';
      case 85:
      case 86:
        return 'Heavy Snow';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Unknown';
    }
  }

  /// Get weather emoji based on weather code
  static String getWeatherEmoji(int weatherCode) {
    switch (weatherCode) {
      case 0:
        return '☀️';
      case 1:
      case 2:
        return '⛅';
      case 3:
        return '☁️';
      case 45:
      case 48:
        return '🌫️';
      case 51:
      case 53:
      case 55:
        return '🌦️';
      case 61:
      case 63:
      case 65:
        return '🌧️';
      case 71:
      case 73:
      case 75:
        return '❄️';
      case 80:
      case 81:
      case 82:
        return '⛈️';
      case 85:
      case 86:
        return '🌨️';
      case 95:
      case 96:
      case 99:
        return '⛈️';
      default:
        return '🌡️';
    }
  }
}
