import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';

const String _bgChannelId = 'safetysafar_bg_service';
const int _bgNotifId = 8888;

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create the persistent foreground notification channel
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _bgChannelId,
    'SafetySafar Protection',
    description: 'Keeps location monitoring active for your safety',
    importance: Importance.low,
    playSound: false,
  );
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _bgChannelId,
      initialNotificationTitle: 'SafetySafar Active',
      initialNotificationContent: 'Monitoring your location for safety alerts',
      foregroundServiceNotificationId: _bgNotifId,
      foregroundServiceTypes: const [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onServiceStart,
    ),
  );
}

Future<void> startBackgroundService() async {
  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();
  if (!isRunning) {
    await service.startService();
  }
}

Future<void> stopBackgroundService() async {
  final service = FlutterBackgroundService();
  service.invoke('stop');
}

// This runs in a separate isolate — keep imports minimal, no BuildContext
@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  await notificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  service.on('stop').listen((_) => service.stopSelf());

  // Update the persistent notification
  service.invoke('update', {'title': 'SafetySafar Active', 'content': 'Monitoring your location'});

  Timer.periodic(const Duration(seconds: 30), (_) async {
    await _pingLocationToBackend(notificationsPlugin);
  });
}

Future<void> _pingLocationToBackend(FlutterLocalNotificationsPlugin notif) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken') ?? '';
    if (token.isEmpty) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final res = await http.post(
      Uri.parse(ApiConfig.trackLocation),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) return;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final anomalies = (data['anomalies'] as List?) ?? [];

    for (final anomaly in anomalies) {
      final type = anomaly['type'] as String? ?? '';
      final zoneName = anomaly['zone_name'] as String? ?? 'Unknown Zone';
      final level = anomaly['danger_level'] as String? ?? 'medium';

      if (type == 'danger_zone_entry') {
        final titles = {
          'critical': '🚨 CRITICAL DANGER ZONE',
          'high': '⚠️ HIGH RISK ZONE ENTERED',
          'medium': '⚠️ CAUTION: Risk Zone',
          'low': '📍 Zone Alert',
        };
        await notif.show(
          zoneName.hashCode.abs(),
          titles[level] ?? '⚠️ Zone Alert',
          'You entered "$zoneName". Stay alert and follow safety guidelines.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'zone_alerts',
              'Danger Zone Alerts',
              channelDescription: 'Alerts when you enter a danger zone',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
          ),
        );
      }
    }
  } catch (_) {}
}
