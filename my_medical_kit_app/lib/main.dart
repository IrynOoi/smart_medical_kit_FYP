//main.dart
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'screens/splash_screen.dart'; // Import the splash screen

void main() {
  // 🌟 Firebase has been removed, so everything is now clean and simple!
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
      home: const SplashScreen(), // Start at the splash screen (loading page)
    );
  }
}

// =======================================================
// Medication History Screen has been moved to lib/screens/medication_history_page.dart
// =======================================================
