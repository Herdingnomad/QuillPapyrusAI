import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_papyrus_ai/models/app_theme_data.dart';
import 'package:quill_papyrus_ai/models/document_template.dart';
import 'package:quill_papyrus_ai/services/themed_export_service.dart';

void main() {
  group('AppThemeData & WCAG Contrast Tests', () {
    test('Hex color parsing and formatting', () {
      expect(AppThemeData.hexToColor('#1e1e2e'), const Color(0xFF1e1e2e));
      expect(AppThemeData.hexToColor('1e1e2e'), const Color(0xFF1e1e2e));
      expect(AppThemeData.hexToColor('#fff'), const Color(0xFFffffff));
      expect(AppThemeData.colorToHex(const Color(0xFF8ec07c)), '#8EC07C');
    });

    test('WCAG 2.1 Contrast calculations and ratings', () {
      // High contrast: White on Black
      final ratioWhiteOnBlack = AppThemeData.getContrastRatio(Colors.white, Colors.black);
      expect(ratioWhiteOnBlack, greaterThanOrEqualTo(20.0));
      expect(AppThemeData.getContrastRating(ratioWhiteOnBlack), contains('AAA'));

      // Gruvbox Dark: fg (#ebdbb2) on bg (#282828)
      final gruvboxRatio = AppThemeData.getContrastRatio(
        AppThemeData.gruvboxDark.fg,
        AppThemeData.gruvboxDark.bg,
      );
      expect(gruvboxRatio, greaterThanOrEqualTo(7.0));
      expect(AppThemeData.getContrastRating(gruvboxRatio), 'AAA (Excellent)');

      // Low contrast test: dark gray on black
      final lowRatio = AppThemeData.getContrastRatio(const Color(0xFF333333), Colors.black);
      expect(lowRatio, lessThan(3.0));
      expect(AppThemeData.getContrastRating(lowRatio), contains('Low Contrast'));
    });

    test('Theme JSON Serialization round-trip', () {
      const theme = AppThemeData.catppuccinMocha;
      final jsonStr = theme.toJson();
      final parsed = AppThemeData.fromJson(jsonStr);

      expect(parsed.name, theme.name);
      expect(parsed.bg, theme.bg);
      expect(parsed.fg, theme.fg);
      expect(parsed.accent, theme.accent);
    });

    test('Default presets contain expected themes', () {
      expect(AppThemeData.defaultPresets.length, greaterThanOrEqualTo(8));
      final names = AppThemeData.defaultPresets.map((t) => t.name).toList();
      expect(names, contains('Gruvbox Dark'));
      expect(names, contains('Catppuccin Mocha'));
      expect(names, contains('Nord Frost'));
      expect(names, contains('Tokyo Night'));
      expect(names, contains('Dracula'));
    });
  });

  group('DocumentTemplate & Variable Expansion Tests', () {
    final testDate = DateTime(2026, 9, 12, 14, 30);

    test('U.S. Date format expands as MM-DD-YYYY', () {
      final tmpl = DocumentTemplate(
        id: 'test_tmpl',
        title: 'Meeting Notes',
        description: 'Sync notes',
        category: 'Work',
        icon: 'groups',
        content: '# {{title}}\nDate: {{date}}\nUS: {{date_us}}\nISO: {{date_iso}}\nEU: {{date_eu}}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = tmpl.applyVariables(
        title: 'Weekly Sync',
        dateFormat: 'us',
        now: testDate,
      );

      expect(result.content, contains('Date: 09-12-2026'));
      expect(result.content, contains('US: 09-12-2026'));
      expect(result.content, contains('ISO: 2026-09-12'));
      expect(result.content, contains('EU: 12-09-2026'));
      expect(result.content, contains('# Weekly Sync'));
    });

    test('ISO and EU Date formats expand correctly', () {
      final tmpl = DocumentTemplate(
        id: 'test_tmpl',
        title: 'Project Plan',
        description: '',
        category: 'Engineering',
        icon: 'rocket',
        content: 'Date: {{date}}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final isoResult = tmpl.applyVariables(dateFormat: 'iso', now: testDate);
      expect(isoResult.content, 'Date: 2026-09-12');

      final euResult = tmpl.applyVariables(dateFormat: 'eu', now: testDate);
      expect(euResult.content, 'Date: 12-09-2026');
    });

    test('{{cursor}} placeholder detection and removal', () {
      final tmpl = DocumentTemplate(
        id: 'cursor_test',
        title: 'Note',
        description: '',
        category: 'General',
        icon: 'description',
        content: 'Header\n\n{{cursor}}\nFooter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = tmpl.applyVariables();
      expect(result.content.contains('{{cursor}}'), false);
      expect(result.cursorOffset, equals(8));
      expect(result.content, 'Header\n\n\nFooter');
    });

    test('Default templates are defined and valid', () {
      final defaults = DocumentTemplate.defaultTemplates;
      expect(defaults.length, greaterThanOrEqualTo(7));
      final titles = defaults.map((d) => d.title).toList();
      expect(titles, contains('Daily Journal & Reflections'));
      expect(titles, contains('Project Specification & RFC'));
      expect(titles, contains('Farm & Field Log'));
    });
  });

  group('ThemedExportService Tests', () {
    test('HTML generation includes active theme CSS variables and GFM elements', () {
      final html = ThemedExportService.instance.generateThemedHtml(
        title: 'Test Note',
        markdownContent: '# Hello World\n\nThis is **bold** text.\n\n> [!NOTE]\n> A note.',
        theme: AppThemeData.tokyoNight,
      );

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<title>Test Note</title>'));
      expect(html, contains(AppThemeData.colorToHex(AppThemeData.tokyoNight.bg)));
      expect(html, contains(AppThemeData.colorToHex(AppThemeData.tokyoNight.accent)));
      expect(html, contains('Theme: Tokyo Night'));
      expect(html, contains('<h1>Hello World</h1>'));
      expect(html, contains('<strong>bold</strong>'));
    });
  });
}
