// screens/splash_screen.dart
// The first screen shown when the app launches. Displays a branded splash screen with a logo,
// app name, tagline, and a loading indicator. After 5 seconds, navigates to the onboarding page.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_medical_kit_app/screens/onboarding_page.dart';
import 'package:my_medical_kit_app/theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // After 5 seconds, navigate to the onboarding page (only if the widget is still mounted)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, // Full width
        // Apply the main gradient defined in the theme colors
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Vertically center content
          children: [
            // Display the splash screen SVG logo
            // --- UPDATED SECTION: increased size from 80 to 150 for better visibility ---
            SvgPicture.asset(
              'assets/images/splash_screen.svg',
              width: 150, // Increased size from 80 to 150
              height: 150, // Increased size from 80 to 150
              // fit: BoxFit.contain, // (optional) preserves aspect ratio
            ),

            // --- END OF UPDATED SECTION ---
            const SizedBox(height: 30), // Spacing between logo and title
            const Text(
              'Smart Medical Kit',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'IoT-Based Medication Management',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(
                  alpha: 0.9,
                ), // Semi-transparent white
              ),
            ),
            const SizedBox(height: 40),
            // Indefinite circular progress indicator (spinner) in white
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
