//splash_screen.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'landing_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 SplashScreen: Initializing...');
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // Navigate to Onboarding after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/medical-smart-kit-logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Smart Medical Kit',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              CircularProgressIndicator(
                color: Colors.white.withValues(alpha: 0.8),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
