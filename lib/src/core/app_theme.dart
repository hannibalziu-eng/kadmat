import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';

import 'design/kadmat_theme_extension.dart';
import 'design/kadmat_tokens.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = KadmatColors.brandPrimary;
  static const Color secondaryColor = KadmatColors.brandSecondary;
  static const Color accentColor = KadmatColors.brandAccent;

  // Dark Mode Colors
  static const Color backgroundDark = KadmatColors.darkBackground;
  static const Color surfaceDark = KadmatColors.darkSurface;
  static const Color borderDark = KadmatColors.darkBorder;
  static const Color textPrimaryDark = KadmatColors.darkTextPrimary;
  static const Color textSecondaryDark = KadmatColors.darkTextSecondary;

  // Glassmorphism Decoration
  static BoxDecoration glassDecoration({
    double? radius,
    Color color = const Color(0xFF1a2b32),
    double opacity = 0.7,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius ?? 16.r),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1.w,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
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
      scaffoldBackgroundColor: KadmatColors.lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: KadmatColors.lightSurface,
      ),
      fontFamily: 'Cairo',
      extensions: const <ThemeExtension<dynamic>>[KadmatSemanticColors.light()],
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
        bodyMedium: TextStyle(
          fontSize: 14.fz,
          color: KadmatColors.lightTextSecondary,
        ),
        titleLarge: TextStyle(
          fontSize: 22.fz,
          fontWeight: FontWeight.w800,
          color: KadmatColors.lightTextPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16.fz,
          fontWeight: FontWeight.w700,
          color: KadmatColors.lightTextPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KadmatColors.lightSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: KadmatColors.lightBorderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: KadmatColors.lightBorderStrong),
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KadmatColors.lightTextPrimary,
          side: const BorderSide(color: KadmatColors.lightBorderStrong),
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          textStyle: TextStyle(fontSize: 15.fz, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: KadmatColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: const BorderSide(color: KadmatColors.lightBorder),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.04),
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
          color: KadmatColors.lightTextPrimary,
        ),
        iconTheme: IconThemeData(
          color: KadmatColors.lightTextPrimary,
          size: 24.s,
        ),
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
      extensions: const <ThemeExtension<dynamic>>[KadmatSemanticColors.dark()],
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
