import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:kadmat/src/core/app_theme.dart';

void main() {
  group('AppTheme Tests', () {
    test('should have consistent primary colors', () {
      expect(AppTheme.primaryColor, const Color(0xFF13b6ec));
      expect(AppTheme.secondaryColor, const Color(0xFF0e8cb5));
      expect(AppTheme.accentColor, const Color(0xFFebf9fc));
    });

    test('should create glass decoration with default parameters', () {
      final decoration = AppTheme.glassDecoration();

      expect(
        decoration.color?.withValues(alpha: 0.7),
        const Color(0xFF1a2b32).withValues(alpha: 0.7),
      );
      expect(decoration.borderRadius, isA<BorderRadius>());
      expect(decoration.boxShadow, isNotEmpty);
    });

    test('should create glass decoration with custom parameters', () {
      final decoration = AppTheme.glassDecoration(
        radius: 20.0,
        color: const Color(0xFF000000),
        opacity: 0.5,
      );

      expect(
        decoration.color?.withValues(alpha: 0.5),
        const Color(0xFF000000).withValues(alpha: 0.5),
      );
      expect(decoration.borderRadius, BorderRadius.circular(20.0));
    });

    test('should have valid light theme', () {
      final lightTheme = AppTheme.lightTheme;

      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.primaryColor, AppTheme.primaryColor);
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF6F8F8));
    });

    test('should have valid dark theme', () {
      final darkTheme = AppTheme.darkTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.primaryColor, AppTheme.primaryColor);
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF101d22));
    });
  });
}
