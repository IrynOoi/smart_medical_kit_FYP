import 'package:flutter/material.dart';

class AppColors {
  // Main Gradient Colors from your new pastel purple image
  static const Color pastelBlue = Color(0xFF9BA3EB);
  static const Color softPurple = Color(0xFFBAA1F7);
  static const Color lightPink = Color(0xFFE2B4FC);

  // Gradient definitions
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pastelBlue, softPurple, lightPink],
  );

  // Theme primary color (using the soft purple)
  static const Color primaryPurple = Color(0xFFBAA1F7);
  
  // Functional colors
  static const Color scaffoldBackground = Colors.white;
  static const Color textDark = Color(0xFF2D3142);
  static const Color textLight = Colors.white;
  static const Color accentColor = Color(0xFF9BA3EB);
}
