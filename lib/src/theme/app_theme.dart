import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const background = Color(0xFF050805);
  static const primary = Color(0xFF00FF41);
  static const secondary = Color(0xFF70A080);
  static const panel = Color(0xFF0B160E);
  static const active = Color(0xFF39FF70);
  static const warning = Color(0xFFE6B450);

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: background,
      secondary: active,
      onSecondary: background,
      surface: panel,
      onSurface: primary,
    ),
    textTheme: const TextTheme(
      labelLarge: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        letterSpacing: 1.5,
        color: secondary,
      ),
      headlineLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'monospace',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: primary,
      ),
      bodyLarge: TextStyle(fontSize: 18, height: 1.5, color: secondary),
    ),
  );
}
