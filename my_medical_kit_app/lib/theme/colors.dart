//theme/colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Premium Purple Gradient Colors (from your image)
  static const Color premiumDark = Color(0xFF3B1E54);
  static const Color premiumMid = Color(0xFF6A4C93);
  static const Color premiumLight = Color(0xFF9B7EBD);

  // Gradient definitions
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [premiumDark, premiumMid, premiumLight],
  );

  // Theme primary color (using the rich purple)
  static const Color primaryPurple = Color(0xFF6A4C93);

  // Functional colors
  static const Color scaffoldBackground = Colors.white;
  static const Color textDark = Color(0xFF2D3142);
  static const Color textLight = Colors.white;
  static const Color accentColor = Color(0xFF9B7EBD);
}
