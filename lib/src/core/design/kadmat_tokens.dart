import 'package:flutter/material.dart';

/// Centralized design tokens used by the app theme and reusable widgets.
class KadmatColors {
  const KadmatColors._();

  static const Color brandPrimary = Color(0xFF0066FF);
  static const Color brandSecondary = Color(0xFF2284FF);
  static const Color brandAccent = Color(0xFFEAF2FF);
  static const Color brandAccentStrong = Color(0xFFD8E7FF);
  static const Color heroPrimaryStart = Color(0xFF1EAEF0);
  static const Color heroPrimaryEnd = Color(0xFF0066FF);
  static const Color lightSurfaceMuted = Color(0xFFF3F7FB);
  static const Color lightSurfaceSoft = Color(0xFFF5F9FF);
  static const Color lightBorderStrong = Color(0xFFD6E0EC);

  static const Color darkBackground = Color(0xFF101D22);
  static const Color darkSurface = Color(0xFF1A2B32);
  static const Color darkBorder = Color(0xFF233F48);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF92BBC9);

  static const Color lightBackground = Color(0xFFF9FAFB);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE3EAF2);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF667085);

  static const Color stateSuccess = Color(0xFF2DB980);
  static const Color stateWarning = Color(0xFFFFA33A);
  static const Color stateError = Color(0xFFE05353);
  static const Color stateInfo = Color(0xFF2F80FF);
}

class KadmatSpacing {
  const KadmatSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class KadmatRadius {
  const KadmatRadius._();

  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class KadmatMotion {
  const KadmatMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
