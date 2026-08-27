import 'package:flutter/material.dart';

class GruvboxColors {
  // Backgrounds
  static const Color bgHard = Color(0xFF1d2021);
  static const Color bg = Color(0xFF282828);
  static const Color bgSoft = Color(0xFF32302f);
  static const Color bg1 = Color(0xFF3c3836);
  static const Color bg2 = Color(0xFF504945);
  static const Color bg3 = Color(0xFF665c54);
  static const Color bg4 = Color(0xFF7c6f64);

  // Foregrounds
  static const Color fg = Color(0xFFebdbb2);
  static const Color fg0 = Color(0xFFfbf1c7);
  static const Color fg1 = Color(0xFFebdbb2);
  static const Color fg2 = Color(0xFFd5c4a1);
  static const Color fg3 = Color(0xFFbdae93);
  static const Color fg4 = Color(0xFFa89984);

  // Grays
  static const Color gray = Color(0xFF928374);

  // Accents
  static const Color red = Color(0xFFfb4934);
  static const Color green = Color(0xFFb8bb26);
  static const Color yellow = Color(0xFFfabd2f);
  static const Color blue = Color(0xFF83a598);
  static const Color purple = Color(0xFFd3869b);
  static const Color aqua = Color(0xFF8ec07c);
  static const Color orange = Color(0xFFfe8019);

  // Neutral accents
  static const Color darkRed = Color(0xFFcc241d);
  static const Color darkGreen = Color(0xFF98971a);
  static const Color darkYellow = Color(0xFFd79921);
  static const Color darkBlue = Color(0xFF458588);
  static const Color darkPurple = Color(0xFFb16286);
  static const Color darkAqua = Color(0xFF689d6a);
  static const Color darkOrange = Color(0xFFd65d0e);

  // Diff colors
  static const Color additionBg = Color(0xFF2d3a2e);
  static const Color deletionBg = Color(0xFF3c2a2a);
}

class GruvboxTheme {
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        surface: GruvboxColors.bg,
        onSurface: GruvboxColors.fg,
        primary: GruvboxColors.blue,
        onPrimary: GruvboxColors.bgHard,
        secondary: GruvboxColors.aqua,
        onSecondary: GruvboxColors.bgHard,
        error: GruvboxColors.red,
        onError: GruvboxColors.bgHard,
      ),
      scaffoldBackgroundColor: GruvboxColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: GruvboxColors.bg1,
        foregroundColor: GruvboxColors.fg,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: GruvboxColors.bg1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: GruvboxColors.bg1,
        filled: true,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: GruvboxColors.aqua),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: GruvboxColors.bg3),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: GruvboxColors.bg3),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: GruvboxColors.fg),
        bodyMedium: TextStyle(color: GruvboxColors.fg),
        bodySmall: TextStyle(color: GruvboxColors.fg),
      ).apply(
        bodyColor: GruvboxColors.fg,
        displayColor: GruvboxColors.fg,
      ),
      iconTheme: const IconThemeData(
        color: GruvboxColors.fg4,
      ),
      dividerTheme: const DividerThemeData(
        color: GruvboxColors.bg3,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GruvboxColors.bgHard,
        selectedItemColor: GruvboxColors.aqua,
        unselectedItemColor: GruvboxColors.gray,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: GruvboxColors.orange,
        foregroundColor: GruvboxColors.bgHard,
      ),
    );
  }
}
