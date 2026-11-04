import 'package:flutter/material.dart';

/// User-selectable writing typefaces for the manuscript editor and live preview.
/// All options include bundled offline font assets so they render crisply
/// on air-gapped Android devices as well as Windows/macOS/Linux desktops.
enum EditorFontFamily {
  literaryProse(
    id: 'literary_prose',
    label: 'Literary Prose',
    shortLabel: 'Prose',
    subtitle: 'Newsreader • Editorial book serif',
    fontFamily: 'Newsreader',
    fallbacks: ['Georgia', 'serif'],
    editorFontSize: 16.0,
    editorLineHeight: 1.68,
    previewFontSize: 15.5,
    isMonospace: false,
    isSerif: true,
  ),
  draftsmanMono(
    id: 'draftsman_mono',
    label: 'Draftsman Mono',
    shortLabel: 'Mono',
    subtitle: 'JetBrains Mono • Precision source',
    fontFamily: 'JetBrainsMono',
    fallbacks: ['Consolas', 'monospace'],
    editorFontSize: 14.2,
    editorLineHeight: 1.62,
    previewFontSize: 14.0,
    isMonospace: true,
    isSerif: false,
  ),
  courierNew(
    id: 'courier_new',
    label: 'Courier New',
    shortLabel: 'Courier',
    subtitle: 'Typewriter & screenplay manuscript',
    fontFamily: 'Courier New',
    fallbacks: ['CourierPrime', 'Courier', 'monospace'],
    editorFontSize: 15.0,
    editorLineHeight: 1.62,
    previewFontSize: 14.5,
    isMonospace: true,
    isSerif: true,
  ),
  helvetica(
    id: 'helvetica',
    label: 'Helvetica',
    shortLabel: 'Helvetica',
    subtitle: 'Swiss neo-grotesque modernist sans',
    fontFamily: 'Helvetica',
    fallbacks: ['Helvetica Neue', 'Arimo', 'Arial', 'sans-serif'],
    editorFontSize: 15.0,
    editorLineHeight: 1.62,
    previewFontSize: 14.8,
    isMonospace: false,
    isSerif: false,
  ),
  roboto(
    id: 'roboto',
    label: 'Roboto',
    shortLabel: 'Roboto',
    subtitle: 'Clean neutral contemporary sans',
    fontFamily: 'Roboto',
    fallbacks: ['sans-serif'],
    editorFontSize: 15.0,
    editorLineHeight: 1.62,
    previewFontSize: 14.8,
    isMonospace: false,
    isSerif: false,
  );

  final String id;
  final String label;
  final String shortLabel;
  final String subtitle;
  final String fontFamily;
  final List<String> fallbacks;
  final double editorFontSize;
  final double editorLineHeight;
  final double previewFontSize;
  final bool isMonospace;
  final bool isSerif;

  const EditorFontFamily({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.fontFamily,
    required this.fallbacks,
    required this.editorFontSize,
    required this.editorLineHeight,
    required this.previewFontSize,
    required this.isMonospace,
    required this.isSerif,
  });

  static EditorFontFamily fromId(String? id) {
    if (id == null || id.isEmpty) return EditorFontFamily.literaryProse;
    for (final item in EditorFontFamily.values) {
      if (item.id == id) return item;
    }
    return EditorFontFamily.literaryProse;
  }

  TextStyle editorStyle({
    required Color color,
    double? fontSizeOverride,
    double? heightOverride,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallbacks,
      fontSize: fontSizeOverride ?? editorFontSize,
      height: heightOverride ?? editorLineHeight,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: isSerif && !isMonospace ? 0.05 : (isMonospace ? 0.0 : -0.1),
    );
  }

  TextStyle previewBodyStyle({
    required Color color,
    double? fontSizeOverride,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallbacks,
      fontSize: fontSizeOverride ?? previewFontSize,
      height: 1.68,
      color: color,
      letterSpacing: isSerif && !isMonospace ? 0.05 : -0.05,
    );
  }
}

/// Centralized typographic scale and roles for Quill & Papyrus Atelier UI.
class AppTypography {
  AppTypography._();

  static const String uiFamily = 'PlusJakartaSans';
  static const String serifFamily = 'Newsreader';
  static const String monoFamily = 'JetBrainsMono';

  static const List<FontFeature> tabularNums = [FontFeature.tabularFigures()];

  static TextStyle brandWordmark(Color color, {double fontSize = 14.5}) {
    return TextStyle(
      fontFamily: serifFamily,
      fontFamilyFallback: const ['Georgia', 'serif'],
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      height: 1.1,
    );
  }

  static TextStyle folioDisplay(Color color, {double fontSize = 26}) {
    return TextStyle(
      fontFamily: serifFamily,
      fontFamilyFallback: const ['Georgia', 'serif'],
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      height: 1.18,
    );
  }

  static TextStyle sectionTitle(Color color, {double fontSize = 15}) {
    return TextStyle(
      fontFamily: serifFamily,
      fontFamilyFallback: const ['Georgia', 'serif'],
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.25,
    );
  }

  static TextStyle uiLabel(
    Color color, {
    double fontSize = 12.0,
    FontWeight fontWeight = FontWeight.w500,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.08,
      fontFeatures: tabular ? tabularNums : null,
    );
  }

  static TextStyle tabularMetric(
    Color color, {
    double fontSize = 11.5,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.05,
      fontFeatures: tabularNums,
    );
  }

  static TextStyle codeMono(
    Color color, {
    double fontSize = 12.5,
    FontWeight fontWeight = FontWeight.w400,
    Color? backgroundColor,
    double height = 1.5,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: const ['CourierPrime', 'monospace'],
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      fontFeatures: tabularNums,
    );
  }

  static TextTheme buildUiTextTheme(Color fg, Color fgMuted) {
    const base = TextStyle(
      fontFamily: uiFamily,
      fontFamilyFallback: ['Roboto', 'sans-serif'],
    );
    return TextTheme(
      displayLarge: TextStyle(fontFamily: serifFamily, color: fg, fontSize: 34, fontWeight: FontWeight.w500, letterSpacing: -0.8),
      displayMedium: TextStyle(fontFamily: serifFamily, color: fg, fontSize: 28, fontWeight: FontWeight.w500, letterSpacing: -0.6),
      displaySmall: TextStyle(fontFamily: serifFamily, color: fg, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.4),
      headlineMedium: TextStyle(fontFamily: serifFamily, color: fg, fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleLarge: base.copyWith(color: fg, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.25),
      titleMedium: base.copyWith(color: fg, fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -0.15),
      titleSmall: base.copyWith(color: fg, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.1),
      bodyLarge: base.copyWith(color: fg, fontSize: 14.5, height: 1.5),
      bodyMedium: base.copyWith(color: fg, fontSize: 13, height: 1.45),
      bodySmall: base.copyWith(color: fgMuted, fontSize: 11.5, height: 1.4),
      labelLarge: base.copyWith(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: -0.05),
      labelMedium: base.copyWith(color: fgMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
      labelSmall: base.copyWith(color: fgMuted, fontSize: 10.5, fontWeight: FontWeight.w500),
    );
  }
}
