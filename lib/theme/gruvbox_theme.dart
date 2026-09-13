import 'package:flutter/material.dart';
import 'package:quill_papyrus_ai/models/app_theme_data.dart';

class GruvboxColors {
  // Active theme pointer
  static AppThemeData _active = AppThemeData.gruvboxDark;
  static void setActiveTheme(AppThemeData theme) {
    _active = theme;
  }
  static AppThemeData get activeTheme => _active;

  // Background layers
  static Color get bgHard => _active.bgHard;
  static Color get bg => _active.bg;
  static Color get bgSoft => Color.lerp(_active.bg, _active.bg1, 0.5) ?? _active.bg1;
  static Color get bg1 => _active.bg1;
  static Color get bg2 => _active.bg2;
  static Color get bg3 => _active.bg3;
  static Color get bg4 => _active.bg4;

  // Foregrounds
  static Color get fg => _active.fg;
  static Color get fg0 => _active.isDark
      ? (Color.lerp(_active.fg, Colors.white, 0.15) ?? _active.fg)
      : (Color.lerp(_active.fg, Colors.black, 0.15) ?? _active.fg);
  static Color get fg1 => _active.fg;
  static Color get fg2 => Color.lerp(_active.fg, _active.fgMuted, 0.3) ?? _active.fg;
  static Color get fg3 => _active.fgMuted;
  static Color get fg4 => _active.fgMuted;

  // Grays / Muted
  static Color get gray => _active.fgMuted;

  // Accents & Semantics
  static Color get accent => _active.accent;
  static Color get accentSecondary => _active.accentSecondary;
  static Color get red => _active.red;
  static Color get green => _active.green;
  static Color get yellow => _active.yellow;
  static Color get blue => _active.blue;
  static Color get purple => _active.purple;
  static Color get aqua => _active.accentSecondary;
  static Color get orange => _active.orange;

  // Neutral / darker accents
  static Color get darkRed => Color.lerp(_active.red, _active.bgHard, 0.25) ?? _active.red;
  static Color get darkGreen => Color.lerp(_active.green, _active.bgHard, 0.25) ?? _active.green;
  static Color get darkYellow => Color.lerp(_active.yellow, _active.bgHard, 0.25) ?? _active.yellow;
  static Color get darkBlue => Color.lerp(_active.blue, _active.bgHard, 0.25) ?? _active.blue;
  static Color get darkPurple => Color.lerp(_active.purple, _active.bgHard, 0.25) ?? _active.purple;
  static Color get darkAqua => Color.lerp(_active.accentSecondary, _active.bgHard, 0.25) ?? _active.accentSecondary;
  static Color get darkOrange => Color.lerp(_active.orange, _active.bgHard, 0.25) ?? _active.orange;

  // Diff colors
  static Color get additionBg => _active.additionBg;
  static Color get deletionBg => _active.deletionBg;
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
