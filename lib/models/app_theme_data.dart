import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppThemeData {
  final String id;
  final String name;
  final bool isDark;
  final bool isCustom;

  // Background layers
  final Color bgHard;
  final Color bg;
  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color bg4;

  // Foregrounds
  final Color fg;
  final Color fgMuted;

  // Accents
  final Color accent;
  final Color accentSecondary;

  // Semantic
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color purple;
  final Color orange;

  // Diffs
  final Color additionBg;
  final Color deletionBg;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.isDark,
    this.isCustom = false,
    required this.bgHard,
    required this.bg,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.bg4,
    required this.fg,
    required this.fgMuted,
    required this.accent,
    required this.accentSecondary,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.purple,
    required this.orange,
    required this.additionBg,
    required this.deletionBg,
  });

  // Hex conversion utilities
  static Color hexToColor(String hex, {Color fallback = Colors.white}) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 3) {
      clean = clean.split('').map((c) => '$c$c').join();
    }
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    if (clean.length != 8) return fallback;
    final val = int.tryParse(clean, radix: 16);
    if (val == null) return fallback;
    return Color(val);
  }

  static String colorToHex(Color color, {bool includeAlpha = false}) {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return includeAlpha ? '#$a$r$g$b'.toUpperCase() : '#$r$g$b'.toUpperCase();
  }

  // WCAG 2.1 Contrast Calculation
  static double getRelativeLuminance(Color color) {
    double transform(double channel) {
      return (channel <= 0.03928)
          ? channel / 12.92
          : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = transform(color.r);
    final g = transform(color.g);
    final b = transform(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double getContrastRatio(Color foreground, Color background) {
    final l1 = getRelativeLuminance(foreground);
    final l2 = getRelativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static String getContrastRating(double ratio) {
    if (ratio >= 7.0) return 'AAA (Excellent)';
    if (ratio >= 4.5) return 'AA (Good)';
    if (ratio >= 3.0) return 'AA Large (Fair)';
    return 'Low Contrast (Poor)';
  }

  static Color getContrastRatingColor(double ratio) {
    if (ratio >= 7.0) return const Color(0xFFb8bb26); // Green
    if (ratio >= 4.5) return const Color(0xFF8ec07c); // Aqua
    if (ratio >= 3.0) return const Color(0xFFfabd2f); // Yellow
    return const Color(0xFFfb4934); // Red
  }

  AppThemeData copyWith({
    String? id,
    String? name,
    bool? isDark,
    bool? isCustom,
    Color? bgHard,
    Color? bg,
    Color? bg1,
    Color? bg2,
    Color? bg3,
    Color? bg4,
    Color? fg,
    Color? fgMuted,
    Color? accent,
    Color? accentSecondary,
    Color? red,
    Color? green,
    Color? yellow,
    Color? blue,
    Color? purple,
    Color? orange,
    Color? additionBg,
    Color? deletionBg,
  }) {
    return AppThemeData(
      id: id ?? this.id,
      name: name ?? this.name,
      isDark: isDark ?? this.isDark,
      isCustom: isCustom ?? this.isCustom,
      bgHard: bgHard ?? this.bgHard,
      bg: bg ?? this.bg,
      bg1: bg1 ?? this.bg1,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      bg4: bg4 ?? this.bg4,
      fg: fg ?? this.fg,
      fgMuted: fgMuted ?? this.fgMuted,
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      red: red ?? this.red,
      green: green ?? this.green,
      yellow: yellow ?? this.yellow,
      blue: blue ?? this.blue,
      purple: purple ?? this.purple,
      orange: orange ?? this.orange,
      additionBg: additionBg ?? this.additionBg,
      deletionBg: deletionBg ?? this.deletionBg,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isDark': isDark ? 1 : 0,
      'isCustom': isCustom ? 1 : 0,
      'colors': {
        'bgHard': colorToHex(bgHard),
        'bg': colorToHex(bg),
        'bg1': colorToHex(bg1),
        'bg2': colorToHex(bg2),
        'bg3': colorToHex(bg3),
        'bg4': colorToHex(bg4),
        'fg': colorToHex(fg),
        'fgMuted': colorToHex(fgMuted),
        'accent': colorToHex(accent),
        'accentSecondary': colorToHex(accentSecondary),
        'red': colorToHex(red),
        'green': colorToHex(green),
        'yellow': colorToHex(yellow),
        'blue': colorToHex(blue),
        'purple': colorToHex(purple),
        'orange': colorToHex(orange),
        'additionBg': colorToHex(additionBg),
        'deletionBg': colorToHex(deletionBg),
      },
    };
  }

  String toJson() => jsonEncode(toMap());

  factory AppThemeData.fromMap(Map<String, dynamic> map) {
    final colors = map['colors'] as Map<String, dynamic>? ?? {};
    return AppThemeData(
      id: map['id'] as String? ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Custom Theme',
      isDark: (map['isDark'] == 1 || map['isDark'] == true),
      isCustom: (map['isCustom'] == 1 || map['isCustom'] == true),
      bgHard: hexToColor(colors['bgHard'] as String? ?? '#1d2021'),
      bg: hexToColor(colors['bg'] as String? ?? '#282828'),
      bg1: hexToColor(colors['bg1'] as String? ?? '#3c3836'),
      bg2: hexToColor(colors['bg2'] as String? ?? '#504945'),
      bg3: hexToColor(colors['bg3'] as String? ?? '#665c54'),
      bg4: hexToColor(colors['bg4'] as String? ?? '#7c6f64'),
      fg: hexToColor(colors['fg'] as String? ?? '#ebdbb2'),
      fgMuted: hexToColor(colors['fgMuted'] as String? ?? '#928374'),
      accent: hexToColor(colors['accent'] as String? ?? '#8ec07c'),
      accentSecondary: hexToColor(colors['accentSecondary'] as String? ?? '#d3869b'),
      red: hexToColor(colors['red'] as String? ?? '#fb4934'),
      green: hexToColor(colors['green'] as String? ?? '#b8bb26'),
      yellow: hexToColor(colors['yellow'] as String? ?? '#fabd2f'),
      blue: hexToColor(colors['blue'] as String? ?? '#83a598'),
      purple: hexToColor(colors['purple'] as String? ?? '#d3869b'),
      orange: hexToColor(colors['orange'] as String? ?? '#fe8019'),
      additionBg: hexToColor(colors['additionBg'] as String? ?? '#2d3a2e'),
      deletionBg: hexToColor(colors['deletionBg'] as String? ?? '#3c2a2a'),
    );
  }

  factory AppThemeData.fromJson(String source) =>
      AppThemeData.fromMap(jsonDecode(source) as Map<String, dynamic>);

  // Built-in Presets
  static const gruvboxDark = AppThemeData(
    id: 'gruvbox_dark',
    name: 'Gruvbox Dark',
    isDark: true,
    bgHard: Color(0xFF1d2021),
    bg: Color(0xFF282828),
    bg1: Color(0xFF3c3836),
    bg2: Color(0xFF504945),
    bg3: Color(0xFF665c54),
    bg4: Color(0xFF7c6f64),
    fg: Color(0xFFebdbb2),
    fgMuted: Color(0xFF928374),
    accent: Color(0xFF8ec07c), // Aqua
    accentSecondary: Color(0xFFd3869b), // Purple
    red: Color(0xFFfb4934),
    green: Color(0xFFb8bb26),
    yellow: Color(0xFFfabd2f),
    blue: Color(0xFF83a598),
    purple: Color(0xFFd3869b),
    orange: Color(0xFFfe8019),
    additionBg: Color(0xFF2d3a2e),
    deletionBg: Color(0xFF3c2a2a),
  );

  static const gruvboxLight = AppThemeData(
    id: 'gruvbox_light',
    name: 'Gruvbox Light',
    isDark: false,
    bgHard: Color(0xFFfbf1c7),
    bg: Color(0xFFf9f5d7),
    bg1: Color(0xFFf2e5bc),
    bg2: Color(0xFFebdbb2),
    bg3: Color(0xFFd5c4a1),
    bg4: Color(0xFFbdae93),
    fg: Color(0xFF3c3836),
    fgMuted: Color(0xFF7c6f64),
    accent: Color(0xFF427b58), // Dark Aqua
    accentSecondary: Color(0xFF8f3f71), // Dark Purple
    red: Color(0xFFcc241d),
    green: Color(0xFF98971a),
    yellow: Color(0xFFb57614),
    blue: Color(0xFF076678),
    purple: Color(0xFF8f3f71),
    orange: Color(0xFFaf3a03),
    additionBg: Color(0xFFe8f5e9),
    deletionBg: Color(0xFFffebee),
  );

  static const catppuccinMocha = AppThemeData(
    id: 'catppuccin_mocha',
    name: 'Catppuccin Mocha',
    isDark: true,
    bgHard: Color(0xFF11111b),
    bg: Color(0xFF1e1e2e),
    bg1: Color(0xFF313244),
    bg2: Color(0xFF45475a),
    bg3: Color(0xFF585b70),
    bg4: Color(0xFF6c7086),
    fg: Color(0xFFcdd6f4),
    fgMuted: Color(0xFFa6adc8),
    accent: Color(0xFF89dceb), // Sky
    accentSecondary: Color(0xFFcba6f7), // Mauve
    red: Color(0xFFf38ba8),
    green: Color(0xFFa6e3a1),
    yellow: Color(0xFFf9e2af),
    blue: Color(0xFF89b4fa),
    purple: Color(0xFFcba6f7),
    orange: Color(0xFFfab387),
    additionBg: Color(0xFF233630),
    deletionBg: Color(0xFF38232c),
  );

  static const nordFrost = AppThemeData(
    id: 'nord_frost',
    name: 'Nord Frost',
    isDark: true,
    bgHard: Color(0xFF242933),
    bg: Color(0xFF2e3440),
    bg1: Color(0xFF3b4252),
    bg2: Color(0xFF434c5e),
    bg3: Color(0xFF4c566a),
    bg4: Color(0xFF616e88),
    fg: Color(0xFFeceff4),
    fgMuted: Color(0xFF8892b0),
    accent: Color(0xFF88c0d0), // Frost
    accentSecondary: Color(0xFFb48ead), // Aurora purple
    red: Color(0xFFbf616a),
    green: Color(0xFFa3be8c),
    yellow: Color(0xFFebcb8b),
    blue: Color(0xFF81a1c1),
    purple: Color(0xFFb48ead),
    orange: Color(0xFFd08770),
    additionBg: Color(0xFF293b35),
    deletionBg: Color(0xFF3a282c),
  );

  static const tokyoNight = AppThemeData(
    id: 'tokyo_night',
    name: 'Tokyo Night',
    isDark: true,
    bgHard: Color(0xFF16161e),
    bg: Color(0xFF1a1b26),
    bg1: Color(0xFF24283b),
    bg2: Color(0xFF2f354a),
    bg3: Color(0xFF414868),
    bg4: Color(0xFF565f89),
    fg: Color(0xFFc0caf5),
    fgMuted: Color(0xFF7aa2f7),
    accent: Color(0xFF7dcfff), // Cyan
    accentSecondary: Color(0xFFbb9af7), // Purple
    red: Color(0xFFf7768e),
    green: Color(0xFF9ece6a),
    yellow: Color(0xFFe0af68),
    blue: Color(0xFF7aa2f7),
    purple: Color(0xFFbb9af7),
    orange: Color(0xFFff9e64),
    additionBg: Color(0xFF20383a),
    deletionBg: Color(0xFF3a1f2b),
  );

  static const dracula = AppThemeData(
    id: 'dracula',
    name: 'Dracula',
    isDark: true,
    bgHard: Color(0xFF21222c),
    bg: Color(0xFF282a36),
    bg1: Color(0xFF44475a),
    bg2: Color(0xFF54586d),
    bg3: Color(0xFF6272a4),
    bg4: Color(0xFF7b8bb8),
    fg: Color(0xFFf8f8f2),
    fgMuted: Color(0xFF8b99c7),
    accent: Color(0xFF8be9fd), // Cyan
    accentSecondary: Color(0xFFff79c6), // Pink
    red: Color(0xFFff5555),
    green: Color(0xFF50fa7b),
    yellow: Color(0xFFf1fa8c),
    blue: Color(0xFF8be9fd),
    purple: Color(0xFFbd93f9),
    orange: Color(0xFFffb86c),
    additionBg: Color(0xFF233b2e),
    deletionBg: Color(0xFF3f2229),
  );

  static const solarizedDark = AppThemeData(
    id: 'solarized_dark',
    name: 'Solarized Dark',
    isDark: true,
    bgHard: Color(0xFF00212b),
    bg: Color(0xFF002b36),
    bg1: Color(0xFF073642),
    bg2: Color(0xFF134654),
    bg3: Color(0xFF586e75),
    bg4: Color(0xFF657b83),
    fg: Color(0xFF93a1a1),
    fgMuted: Color(0xFF586e75),
    accent: Color(0xFF2aa198), // Cyan
    accentSecondary: Color(0xFF6c71c4), // Violet
    red: Color(0xFFdc322f),
    green: Color(0xFF859900),
    yellow: Color(0xFFb58900),
    blue: Color(0xFF268bd2),
    purple: Color(0xFF6c71c4),
    orange: Color(0xFFcb4b16),
    additionBg: Color(0xFF0f3830),
    deletionBg: Color(0xFF381b1c),
  );

  static const monokaiPro = AppThemeData(
    id: 'monokai_pro',
    name: 'Monokai Pro',
    isDark: true,
    bgHard: Color(0xFF19181a),
    bg: Color(0xFF221f22),
    bg1: Color(0xFF2d2a2e),
    bg2: Color(0xFF403e41),
    bg3: Color(0xFF5b595c),
    bg4: Color(0xFF727072),
    fg: Color(0xFFfcfcfa),
    fgMuted: Color(0xFF939293),
    accent: Color(0xFF78dce8), // Cyan
    accentSecondary: Color(0xFFab9df2), // Purple
    red: Color(0xFFff6188),
    green: Color(0xFFa9dc76),
    yellow: Color(0xFFffd866),
    blue: Color(0xFF78dce8),
    purple: Color(0xFFab9df2),
    orange: Color(0xFFfc9867),
    additionBg: Color(0xFF27382d),
    deletionBg: Color(0xFF3e2129),
  );

  static const List<AppThemeData> defaultPresets = [
    gruvboxDark,
    gruvboxLight,
    catppuccinMocha,
    nordFrost,
    tokyoNight,
    dracula,
    solarizedDark,
    monokaiPro,
  ];
}
