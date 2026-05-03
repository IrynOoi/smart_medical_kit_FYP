//main.dart
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'screens/splash_screen.dart';
import 'package:my_medical_kit_app/screens/landing_page.dart';
import 'package:my_medical_kit_app/screens/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App started: WidgetsFlutterBinding initialized.');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Medical Kit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryPurple),
        useMaterial3: true,
      ),
      // Define your routes here
      routes: {
        '/': (context) => const SplashScreen(),
        '/landing': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
      },
      initialRoute: '/',
    );
  }
}
