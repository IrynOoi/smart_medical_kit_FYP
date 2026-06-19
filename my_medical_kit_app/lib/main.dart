// main.dart - The entry point of the Flutter application.
// It initializes the app, loads environment variables, sets up background services,
// and defines the routing for the entire application.

import 'package:flutter/material.dart';
import 'theme/colors.dart'; // Custom color palette
import 'screens/splash_screen.dart'; // Splash screen (first screen)
import 'package:my_medical_kit_app/screens/landing_page.dart'; // Landing page after splash
import 'package:my_medical_kit_app/screens/login_page.dart'; // Login screen
import 'package:my_medical_kit_app/screens/caregiver/caregiver_notifications_page.dart'; // Caregiver notifications
import 'package:my_medical_kit_app/screens/patient/smart_reminder_page.dart'; // Patient smart reminder screen

// 👇 1. Import the ReminderService (used for background reminders/alarms)
import 'package:my_medical_kit_app/services/reminder_service.dart';
import 'package:my_medical_kit_app/services/app_navigator.dart'; // Global navigator key for app-wide navigation

import 'package:flutter_dotenv/flutter_dotenv.dart'; // Load .env variables

// 👇 2. Change void main() to Future<void> main() async because we need to perform async initialization.
Future<void> main() async {
  // Ensure that the Flutter binding is initialized (required for plugins like shared_preferences, etc.)
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from the .env file (e.g., API base URL, keys)
  await dotenv.load(fileName: ".env");

  // Initialize the reminder service (sets up background callbacks, alarm scheduling)
  await ReminderService.init();

  // Print a debug message to confirm the app has started
  debugPrint('🚀 App started: WidgetsFlutterBinding initialized.');

  // Run the app – MyApp is the root widget
  runApp(const MyApp());
}

// The root widget of the application – defines the MaterialApp with routes.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Global navigator key: used to navigate from anywhere in the app
      navigatorKey: appNavigatorKey,

      // Hide the debug banner in the top-right corner
      debugShowCheckedModeBanner: false,

      // App title (visible in the task manager / OS)
      title: 'Smart Medical Kit',

      // Theme configuration – uses the primary purple color as seed
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryPurple),
        useMaterial3: true, // Enable Material 3 design
      ),

      // Define named routes for easy navigation
      routes: {
        '/': (context) => const SplashScreen(), // Initial route
        '/landing': (context) => const LandingPage(), // After splash
        '/login': (context) => const LoginPage(), // Login screen
        '/smart-reminder': (context) =>
            const SmartReminderPage(), // Patient's smart reminder view
        '/caregiver-notifications':
            (context) => // Caregiver notifications list
                const CaregiverNotificationsPage(),
      },

      // The initial route is the splash screen ('/')
      initialRoute: '/',
    );
  }
}
