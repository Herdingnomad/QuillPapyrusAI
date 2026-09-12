import 'package:flutter/material.dart';
import 'package:quill_papyrus_ai/models/app_theme_data.dart';

class GruvboxColors {
  // Constant Gruvbox Palette (Fallback & Defaults)
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

  // Active theme pointer
  static AppThemeData _active = AppThemeData.gruvboxDark;
  static void setActiveTheme(AppThemeData theme) {
    _active = theme;
  }
  static AppThemeData get activeTheme => _active;
}

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final AppThemeData data;
  const AppThemeColors(this.data);

  @override
  AppThemeColors copyWith({AppThemeData? data}) => AppThemeColors(data ?? this.data);

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return this;
  }
}

extension AppThemeContext on BuildContext {
  AppThemeData get appTheme {
    final ext = Theme.of(this).extension<AppThemeColors>();
    return ext?.data ?? GruvboxColors.activeTheme;
  }
}

class GruvboxTheme {
  static ThemeData darkTheme([AppThemeData? theme]) {
    return buildTheme(theme ?? GruvboxColors.activeTheme);
  }

  static ThemeData buildTheme(AppThemeData theme) {
    final isDark = theme.isDark;
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: theme.bg,
        onSurface: theme.fg,
        primary: theme.accent,
        onPrimary: theme.bgHard,
        secondary: theme.accentSecondary,
        onSecondary: theme.bgHard,
        error: theme.red,
        onError: theme.bgHard,
      ),
      scaffoldBackgroundColor: theme.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: theme.bg1,
        foregroundColor: theme.fg,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: theme.bg1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: theme.bg1,
        filled: true,
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.accent),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.bg3),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: theme.bg3),
        ),
      ),
      textTheme: const TextTheme().apply(
        bodyColor: theme.fg,
        displayColor: theme.fg,
      ),
      iconTheme: IconThemeData(
        color: theme.fgMuted,
      ),
      dividerTheme: DividerThemeData(
        color: theme.bg3,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.bgHard,
        selectedItemColor: theme.accent,
        unselectedItemColor: theme.fgMuted,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: theme.orange,
        foregroundColor: theme.bgHard,
      ),
      extensions: [
        AppThemeColors(theme),
      ],
    );
  }
}
