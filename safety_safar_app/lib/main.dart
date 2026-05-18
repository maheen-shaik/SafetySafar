import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'login_role_selector_screen.dart';
import 'login_screen.dart';
import 'registration_screen.dart';
import 'reset_password_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/tourist_dashboard.dart';
import 'screens/authority_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'services/notification_service.dart';
import 'services/background_location_service.dart';

// Handle FCM messages when app is fully terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notif = message.notification;
  if (notif == null) return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin.show(
    message.hashCode,
    notif.title ?? 'SafetySafar Alert',
    notif.body ?? '',
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  // Initialize background location service (does not require Firebase)
  await initBackgroundService();

  try {
    await Firebase.initializeApp();
    debugPrint('[Firebase] ✓ Firebase initialized successfully');

    // Register background FCM handler (app fully killed)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Show notification when FCM arrives and app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notif = message.notification;
      if (notif != null) {
        await NotificationService.showRawAlert(
          title: notif.title ?? 'SafetySafar Alert',
          body: notif.body ?? '',
        );
      }
    });
  } catch (e) {
    debugPrint("[Firebase] ✗ Initialization failed: $e");
  }

  runApp(const SafetySafarApp());
}

class SafetySafarApp extends StatelessWidget {
  const SafetySafarApp({super.key});

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      final role = prefs.getString('role') ?? 'tourist';
      final authToken = prefs.getString('authToken') ?? '';
      final userId = prefs.getString('userId') ?? '';

      if (role == 'admin') {
        return AdminDashboard(authToken: authToken, userId: userId);
      } else if (role == 'authority') {
        return AuthorityDashboard(authToken: authToken, userId: userId);
      }
      return TouristDashboard(authToken: authToken, userId: userId);
    }

    return const LoginRoleSelectorScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safety Safar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E3A7E),
          primary: const Color(0xFF0E3A7E),
          secondary: const Color(0xFFFF7A00),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Outfit'),
          bodyMedium: TextStyle(fontFamily: 'Outfit'),
          titleLarge: TextStyle(fontFamily: 'Outfit'),
          titleMedium: TextStyle(fontFamily: 'Outfit'),
          labelLarge: TextStyle(fontFamily: 'Outfit'),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data!;
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/reset_password': (context) => const ResetPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/weather': (context) => const WeatherScreen(),
      },
    );
  }
}
