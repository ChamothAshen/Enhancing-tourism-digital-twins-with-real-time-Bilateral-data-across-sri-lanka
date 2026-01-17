import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color secondaryGreen = Color(0xFF2E7D32);
  static const Color stoneWhite = Color(0xFFF5F5F5);
  static const Color darkStone = Color(0xFF2D2D2D);
  static const Color accentMaroon = Color(0xFF880E4F);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: secondaryGreen,
      ),
      scaffoldBackgroundColor: stoneWhite,
    );
  }
}
