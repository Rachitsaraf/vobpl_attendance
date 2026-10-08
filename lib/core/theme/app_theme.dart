import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryOrange = Color(0xFFFF7A00); // True Orange
  static const Color secondaryOrange = Color(0xFFFF9124); // Lighter Orange for gradient
  static const Color bgLight = Color(0xFFF7F7F9);
  static const Color darkNavy = Color(0xFF172B6B);
  static const Color secondaryText = Color(0xFF8A8A8A);
  
  static const Color lightOrangeBg = Color(0xFFFFF1E3);
  static const Color lightGreenBg = Color(0xFFEAF7ED);
  static const Color lightBlueBg = Color(0xFFE8F3FF);
  
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color accentBlue = Color(0xFF2196F3);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryOrange,
      primary: primaryOrange,
      surface: Colors.white,
      background: bgLight,
    ),
    scaffoldBackgroundColor: bgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: darkNavy, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(color: darkNavy),
      labelMedium: TextStyle(color: secondaryText),
    ),
  );
}
