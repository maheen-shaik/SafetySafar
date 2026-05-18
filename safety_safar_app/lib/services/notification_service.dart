import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidSettings));
    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showZoneEntryAlert({
    required String zoneName,
    required String dangerLevel,
    required String zoneType,
  }) async {
    final levelLabel = dangerLevel.toUpperCase();
    final typeLabel = zoneType.replaceAll('_', ' ').toUpperCase();

    String title;
    switch (dangerLevel) {
      case 'critical':
        title = 'CRITICAL DANGER ZONE';
        break;
      case 'high':
        title = 'HIGH RISK ZONE ENTERED';
        break;
      case 'medium':
        title = 'CAUTION: Risk Zone Ahead';
        break;
      default:
        title = 'Zone Alert';
    }

    await _plugin.show(
      zoneName.hashCode.abs(),
      title,
      '$zoneName\nThreat: $typeLabel  |  Level: $levelLabel',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'zone_alerts',
          'Danger Zone Alerts',
          channelDescription: 'Alerts when you enter a danger zone',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            'You have entered "$zoneName"\n\nThreat type: $typeLabel\nDanger level: $levelLabel\n\nStay alert and follow safety guidelines.',
            summaryText: 'SafetySafar',
          ),
        ),
      ),
    );
  }

  static Future<void> showRawAlert({required String title, required String body}) async {
    await _plugin.show(
      title.hashCode.abs(),
      title,
      body,
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

  static Future<void> showZoneExitAlert({required String zoneName}) async {
    await _plugin.show(
      ('exit_$zoneName').hashCode.abs(),
      'Left Danger Zone',
      'You have exited "$zoneName". You are now in a safer area.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'zone_alerts',
          'Danger Zone Alerts',
          channelDescription: 'Alerts when you enter a danger zone',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
        ),
      ),
    );
  }

}
