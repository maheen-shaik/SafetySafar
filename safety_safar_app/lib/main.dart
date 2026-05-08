import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'registration_screen.dart';
import 'reset_password_screen.dart';
import 'services/notification_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  try {
    await Firebase.initializeApp();
    debugPrint('[Firebase] ✓ Firebase initialized successfully');
  } catch (e) {
    debugPrint("[Firebase] ✗ Initialization failed: $e. Ensure google-services.json is present.");
  }
  runApp(const SafetySafarApp());
}

class SafetySafarApp extends StatelessWidget {
  const SafetySafarApp({super.key});

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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/reset_password': (context) => const ResetPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        // Note: TouristDashboard and AuthorityDashboard are navigated via Navigator.push
        // because they require authToken and userId parameters at runtime
      },
    );
  }
}