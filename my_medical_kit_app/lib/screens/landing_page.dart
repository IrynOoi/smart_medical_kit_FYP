// landing_page.dart – The first screen users see after the splash screen.
// Displays the app logo, tagline, and two action buttons: Login and Create Account.
// Uses an animated fade‑in + slide‑up effect for the hero section.

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/screens/login_page.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'register_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Make the container fill the entire screen.
        width: double.infinity,
        // Apply the main gradient background (purple to lighter purple) from theme.
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ------------------------------------------------------------------
            // Animated Hero Section: Logo + App Name + Tagline
            // Fades in and slides up from below over 1 second.
            // ------------------------------------------------------------------
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value, // 0 → 1
                  child: Transform.translate(
                    // Start 50 pixels below its final position, then move up.
                    offset: Offset(0, 50 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  // Extra padding gives the SVG room so the bottom edge
                  // of the circular graphic isn't clipped.
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 10,
                      left: 10,
                      right: 10,
                      bottom:
                          20, // ensures the bottom of the circle is fully visible
                    ),
                    child: SvgPicture.asset(
                      'assets/images/medical-smart-kit-logo (1).svg',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // App name: MedSmart
                  const Text(
                    'MedSmart',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tagline
                  Text(
                    'Advanced Pill Monitoring',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
            // ------------------------------------------------------------------
            // Action Buttons: Login and Create Account
            // ------------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 45),
              child: Column(
                children: [
                  // LOG IN button (filled white with purple text)
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the LoginPage.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryPurple,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                      shadowColor: Colors.black45,
                    ),
                    child: const Text(
                      'LOG IN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  // CREATE ACCOUNT button (outlined white border)
                  OutlinedButton(
                    onPressed: () {
                      // Navigate to the RegisterPage.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2.5),
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'CREATE ACCOUNT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // Bottom spacing
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
