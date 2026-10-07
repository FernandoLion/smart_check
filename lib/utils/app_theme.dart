import 'package:flutter/material.dart';

class AppTheme {
  // Colores de Cupertino Midnight (Stitch)
  static const Color background = Color(0xFF131315);
  static const Color surfaceElevated = Color(0xFF1C1C1E);
  static const Color surfaceControl = Color(0xFF2C2C2E);

  static const Color primary = Color(0xFF5E5CE6); // Electric Indigo
  static const Color secondary = Color(0xFF0A84FF); // System Blue
  static const Color success = Color(0xFF30D158); // Soft Neon Green
  static const Color error = Color(0xFFFF453A); // System Red

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);

  static const Color borderSubtle = Color(0x14FFFFFF); // rgba(255,255,255,0.08)

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surfaceElevated,
        error: error,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        headlineLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        headlineMedium: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceControl,
        hintStyle: const TextStyle(color: textSecondary, fontSize: 17),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          elevation: 0,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: secondary),
      ),
    );
  }
}
