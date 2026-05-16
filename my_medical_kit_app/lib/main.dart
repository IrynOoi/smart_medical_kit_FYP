// main.dart
import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'screens/splash_screen.dart';
import 'package:my_medical_kit_app/screens/landing_page.dart';
import 'package:my_medical_kit_app/screens/login_page.dart';
import 'package:my_medical_kit_app/screens/patient/smart_reminder_page.dart';

// 👇 1. 导入你的 ReminderService
import 'package:my_medical_kit_app/services/reminder_service.dart';
import 'package:my_medical_kit_app/services/app_navigator.dart';

// 👇 2. 把 void main() 改成 Future<void> main() async
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ReminderService.init();

  // 👇 3. 加上这一行！这会唤醒你的后台任务和通知系统
  await ReminderService.init();

  debugPrint('🚀 App started: WidgetsFlutterBinding initialized.');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
        '/smart-reminder': (context) => const SmartReminderPage(),
      },
      initialRoute: '/',
    );
  }
}
