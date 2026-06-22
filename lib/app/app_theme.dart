import 'package:flutter/material.dart';

abstract final class PonderaColors {
  static const brandBlue = Color(0xFF0077B6);
  static const lightBackground = Color(0xFFF3F6F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF101820);
  static const darkSurface = Color(0xFF17232D);
  static const successLight = Color(0xFF287A3D);
  static const successDark = Color(0xFF9BE564);
  static const warningLight = Color(0xFF9A6700);
  static const warningDark = Color(0xFFFFB74D);
  static const weightLight = Color(0xFF8A5A00);
  static const weightDark = Color(0xFFFFD33D);
}

ThemeData buildPonderaTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: PonderaColors.brandBlue,
    brightness: brightness,
    surface: isDark ? PonderaColors.darkSurface : PonderaColors.lightSurface,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? PonderaColors.darkBackground
        : PonderaColors.lightBackground,
    fontFamily: 'IBMPlexSans',
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark
          ? PonderaColors.darkSurface
          : PonderaColors.lightSurface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      toolbarHeight: 64,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

ThemeMode themeModeFromPreference(String value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
