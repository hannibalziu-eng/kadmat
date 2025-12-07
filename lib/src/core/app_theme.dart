import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF13b6ec);
  static const Color secondaryColor = Color(0xFF0e8cb5);
  static const Color accentColor = Color(0xFFebf9fc);

  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF101d22);
  static const Color surfaceDark = Color(0xFF1a2b32);
  static const Color borderDark = Color(0xFF233f48);
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFF92bbc9);

  // Glassmorphism Decoration
  static BoxDecoration glassDecoration({
    double? radius,
    Color color = const Color(0xFF1a2b32),
    double opacity = 0.7,
  }) {
    return BoxDecoration(
      color: color.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius ?? 16.r),
      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.w),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10.r,
          spreadRadius: 0,
        ),
      ],
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF6F8F8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
        background: const Color(0xFFF6F8F8),
      ),
      fontFamily: 'Cairo',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32.fz,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        displayMedium: TextStyle(
          fontSize: 28.fz,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        bodyLarge: TextStyle(fontSize: 16.fz, color: Colors.black87),
        bodyMedium: TextStyle(fontSize: 14.fz, color: Colors.black54),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20.fz,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        iconTheme: IconThemeData(color: Colors.black87, size: 24.s),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundDark,
      cardColor: surfaceDark,
      dividerColor: borderDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSurface: textPrimaryDark,
      ),
      fontFamily: 'Cairo',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32.fz,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        displayMedium: TextStyle(
          fontSize: 28.fz,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        headlineMedium: TextStyle(
          fontSize: 24.fz,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        bodyLarge: TextStyle(fontSize: 16.fz, color: textPrimaryDark),
        bodyMedium: TextStyle(fontSize: 14.fz, color: textSecondaryDark),
        bodySmall: TextStyle(fontSize: 12.fz, color: textSecondaryDark),
      ),
      iconTheme: const IconThemeData(color: textSecondaryDark),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        hintStyle: TextStyle(color: textSecondaryDark, fontSize: 14.fz),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: TextStyle(fontSize: 14.fz, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: borderDark),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20.fz,
          fontWeight: FontWeight.bold,
          color: textPrimaryDark,
        ),
        iconTheme: IconThemeData(color: textSecondaryDark, size: 24.s),
      ),
    );
  }
}
