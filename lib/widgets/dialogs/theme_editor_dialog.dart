import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/app_theme_data.dart';
import 'package:quill_papyrus_ai/providers/theme_provider.dart';

Future<AppThemeData?> showThemeEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  AppThemeData? initialTheme,
}) async {
  return showDialog<AppThemeData>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ThemeEditorDialog(initialTheme: initialTheme),
  );
}

class ThemeEditorDialog extends ConsumerStatefulWidget {
  final AppThemeData? initialTheme;

  const ThemeEditorDialog({super.key, this.initialTheme});

  @override
  ConsumerState<ThemeEditorDialog> createState() => _ThemeEditorDialogState();
}

class _ThemeEditorDialogState extends ConsumerState<ThemeEditorDialog> {
  late final TextEditingController _nameController;
  late bool _isDark;

  // Hex string controllers for each color slot
  late final TextEditingController _bgHardCtrl;
  late final TextEditingController _bgCtrl;
  late final TextEditingController _bg1Ctrl;
  late final TextEditingController _bg2Ctrl;
  late final TextEditingController _bg3Ctrl;
  late final TextEditingController _fgCtrl;
  late final TextEditingController _fgMutedCtrl;
  late final TextEditingController _accentCtrl;
  late final TextEditingController _accent2Ctrl;
  late final TextEditingController _redCtrl;
  late final TextEditingController _greenCtrl;
  late final TextEditingController _yellowCtrl;
  late final TextEditingController _blueCtrl;
  late final TextEditingController _purpleCtrl;
  late final TextEditingController _orangeCtrl;

  @override
  void initState() {
    super.initState();
    final base = widget.initialTheme ?? AppThemeData.gruvboxDark;
    _nameController = TextEditingController(
      text: widget.initialTheme != null ? '${widget.initialTheme!.name} (Edited)' : 'My Custom Theme',
    );
    _isDark = base.isDark;

    _bgHardCtrl = TextEditingController(text: AppThemeData.colorToHex(base.bgHard));
    _bgCtrl = TextEditingController(text: AppThemeData.colorToHex(base.bg));
    _bg1Ctrl = TextEditingController(text: AppThemeData.colorToHex(base.bg1));
    _bg2Ctrl = TextEditingController(text: AppThemeData.colorToHex(base.bg2));
    _bg3Ctrl = TextEditingController(text: AppThemeData.colorToHex(base.bg3));
    _fgCtrl = TextEditingController(text: AppThemeData.colorToHex(base.fg));
    _fgMutedCtrl = TextEditingController(text: AppThemeData.colorToHex(base.fgMuted));
    _accentCtrl = TextEditingController(text: AppThemeData.colorToHex(base.accent));
    _accent2Ctrl = TextEditingController(text: AppThemeData.colorToHex(base.accentSecondary));
    _redCtrl = TextEditingController(text: AppThemeData.colorToHex(base.red));
    _greenCtrl = TextEditingController(text: AppThemeData.colorToHex(base.green));
    _yellowCtrl = TextEditingController(text: AppThemeData.colorToHex(base.yellow));
    _blueCtrl = TextEditingController(text: AppThemeData.colorToHex(base.blue));
    _purpleCtrl = TextEditingController(text: AppThemeData.colorToHex(base.purple));
    _orangeCtrl = TextEditingController(text: AppThemeData.colorToHex(base.orange));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bgHardCtrl.dispose();
    _bgCtrl.dispose();
    _bg1Ctrl.dispose();
    _bg2Ctrl.dispose();
    _bg3Ctrl.dispose();
    _fgCtrl.dispose();
    _fgMutedCtrl.dispose();
    _accentCtrl.dispose();
    _accent2Ctrl.dispose();
    _redCtrl.dispose();
    _greenCtrl.dispose();
    _yellowCtrl.dispose();
    _blueCtrl.dispose();
    _purpleCtrl.dispose();
    _orangeCtrl.dispose();
    super.dispose();
  }

  Color _parse(TextEditingController ctrl, Color fallback) {
    return AppThemeData.hexToColor(ctrl.text.trim(), fallback: fallback);
  }

  AppThemeData _buildCurrentDraft() {
    final base = widget.initialTheme ?? AppThemeData.gruvboxDark;
    return AppThemeData(
      id: widget.initialTheme?.isCustom == true
          ? widget.initialTheme!.id
          : 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty ? 'Custom Theme' : _nameController.text.trim(),
      isDark: _isDark,
      isCustom: true,
      bgHard: _parse(_bgHardCtrl, base.bgHard),
      bg: _parse(_bgCtrl, base.bg),
      bg1: _parse(_bg1Ctrl, base.bg1),
      bg2: _parse(_bg2Ctrl, base.bg2),
      bg3: _parse(_bg3Ctrl, base.bg3),
      bg4: _parse(_bg3Ctrl, base.bg4),
      fg: _parse(_fgCtrl, base.fg),
      fgMuted: _parse(_fgMutedCtrl, base.fgMuted),
      accent: _parse(_accentCtrl, base.accent),
      accentSecondary: _parse(_accent2Ctrl, base.accentSecondary),
      red: _parse(_redCtrl, base.red),
      green: _parse(_greenCtrl, base.green),
      yellow: _parse(_yellowCtrl, base.yellow),
      blue: _parse(_blueCtrl, base.blue),
      purple: _parse(_purpleCtrl, base.purple),
      orange: _parse(_orangeCtrl, base.orange),
      additionBg: _isDark ? const Color(0xFF233b2e) : const Color(0xFFe8f5e9),
      deletionBg: _isDark ? const Color(0xFF3f2229) : const Color(0xFFffebee),
    );
  }

  void _harmonizeFromSeed(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    setState(() {
      if (_isDark) {
        final bgH = hsl.withLightness(0.09).withSaturation(0.20).toColor();
        final bgM = hsl.withLightness(0.12).withSaturation(0.22).toColor();
        final bg1 = hsl.withLightness(0.16).withSaturation(0.24).toColor();
        final bg2 = hsl.withLightness(0.21).withSaturation(0.24).toColor();
        final bg3 = hsl.withLightness(0.28).withSaturation(0.22).toColor();
        final fg = hsl.withLightness(0.90).withSaturation(0.18).toColor();
        final fgMuted = hsl.withLightness(0.65).withSaturation(0.25).toColor();

        _bgHardCtrl.text = AppThemeData.colorToHex(bgH);
        _bgCtrl.text = AppThemeData.colorToHex(bgM);
        _bg1Ctrl.text = AppThemeData.colorToHex(bg1);
        _bg2Ctrl.text = AppThemeData.colorToHex(bg2);
        _bg3Ctrl.text = AppThemeData.colorToHex(bg3);
        _fgCtrl.text = AppThemeData.colorToHex(fg);
        _fgMutedCtrl.text = AppThemeData.colorToHex(fgMuted);
      } else {
        final bgH = hsl.withLightness(0.97).withSaturation(0.15).toColor();
        final bgM = hsl.withLightness(0.94).withSaturation(0.18).toColor();
        final bg1 = hsl.withLightness(0.90).withSaturation(0.20).toColor();
        final bg2 = hsl.withLightness(0.85).withSaturation(0.22).toColor();
        final bg3 = hsl.withLightness(0.75).withSaturation(0.20).toColor();
        final fg = hsl.withLightness(0.15).withSaturation(0.25).toColor();
        final fgMuted = hsl.withLightness(0.40).withSaturation(0.20).toColor();

        _bgHardCtrl.text = AppThemeData.colorToHex(bgH);
        _bgCtrl.text = AppThemeData.colorToHex(bgM);
        _bg1Ctrl.text = AppThemeData.colorToHex(bg1);
        _bg2Ctrl.text = AppThemeData.colorToHex(bg2);
        _bg3Ctrl.text = AppThemeData.colorToHex(bg3);
        _fgCtrl.text = AppThemeData.colorToHex(fg);
        _fgMutedCtrl.text = AppThemeData.colorToHex(fgMuted);
      }
      _accentCtrl.text = AppThemeData.colorToHex(seed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = _buildCurrentDraft();
    final fgOnBgContrast = AppThemeData.getContrastRatio(draft.fg, draft.bg);
    final accentOnBgContrast = AppThemeData.getContrastRatio(draft.accent, draft.bg);

    return Dialog(
      backgroundColor: draft.bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: draft.bg3),
      ),
      child: Container(
        width: 820,
        height: 680,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.palette, color: draft.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.initialTheme != null ? 'Edit Color Theme' : 'Create Custom Hex Theme',
                    style: TextStyle(
                      color: draft.fg,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: draft.fgMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Control Bar: Theme Name, Dark/Light Mode, Auto-Harmonize
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(color: draft.fg, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Theme Name',
                      labelStyle: TextStyle(color: draft.fgMuted, fontSize: 13),
                      filled: true,
                      fillColor: draft.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: draft.bg3),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: draft.bg3),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: draft.accent),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: draft.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: draft.bg3),
                  ),
                  child: Row(
                    children: [
                      Icon(_isDark ? Icons.dark_mode : Icons.light_mode, color: draft.yellow, size: 18),
                      const SizedBox(width: 6),
                      Text(_isDark ? 'Dark Base' : 'Light Base', style: TextStyle(color: draft.fg, fontSize: 13)),
                      Switch(
                        value: _isDark,
                        activeThumbColor: draft.accent,
                        onChanged: (val) {
                          setState(() => _isDark = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: draft.accent,
                    foregroundColor: draft.bgHard,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Auto-Harmonize'),
                  onPressed: () {
                    _harmonizeFromSeed(draft.accent);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main 2-Column Area: Left = Hex Color Editors, Right = Real-time WCAG Guide & Markdown Preview
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Scrollable Hex Input Grid
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: draft.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: draft.bg3),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BACKGROUND LAYERS',
                              style: TextStyle(color: draft.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            _buildHexField('Hard Background (Nav & Rails)', _bgHardCtrl, draft.bgHard),
                            _buildHexField('Main Editor Background', _bgCtrl, draft.bg),
                            _buildHexField('Cards & Dialogs (bg1)', _bg1Ctrl, draft.bg1),
                            _buildHexField('Hover & Secondary (bg2)', _bg2Ctrl, draft.bg2),
                            _buildHexField('Borders & Dividers (bg3)', _bg3Ctrl, draft.bg3),
                            const SizedBox(height: 14),

                            Text(
                              'FOREGROUNDS & TEXT',
                              style: TextStyle(color: draft.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            _buildHexField('Main Body Text', _fgCtrl, draft.fg),
                            _buildHexField('Muted / Comments / Gray', _fgMutedCtrl, draft.fgMuted),
                            const SizedBox(height: 14),

                            Text(
                              'ACCENTS & BRAND',
                              style: TextStyle(color: draft.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            _buildHexField('Primary Accent (Buttons, Highlights)', _accentCtrl, draft.accent),
                            _buildHexField('Secondary Accent (Tags, Badges)', _accent2Ctrl, draft.accentSecondary),
                            const SizedBox(height: 14),

                            Text(
                              'SEMANTIC & SYNTAX',
                              style: TextStyle(color: draft.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            _buildHexField('Red (Errors & Deletions)', _redCtrl, draft.red),
                            _buildHexField('Green (Success & Additions)', _greenCtrl, draft.green),
                            _buildHexField('Yellow (Warnings & Bullets)', _yellowCtrl, draft.yellow),
                            _buildHexField('Blue (Links & Info)', _blueCtrl, draft.blue),
                            _buildHexField('Purple (Topics & Metadata)', _purpleCtrl, draft.purple),
                            _buildHexField('Orange (FAB & CTAs)', _orangeCtrl, draft.orange),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right Column: Live WCAG Guide & Markdown Mini-Preview
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Real-Time WCAG 2.1 Contrast Guide
                        _buildContrastGuide(draft, fgOnBgContrast, accentOnBgContrast),
                        const SizedBox(height: 12),

                        // Real-time Markdown Document Preview
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: draft.bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: draft.bg3),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.remove_red_eye_outlined, size: 14, color: draft.fgMuted),
                                      const SizedBox(width: 6),
                                      Text(
                                        'LIVE THEME PREVIEW',
                                        style: TextStyle(color: draft.fgMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),

                                  // H1
                                  Text(
                                    '# Heading 1 Preview',
                                    style: TextStyle(color: draft.green, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),

                                  // H2
                                  Text(
                                    '## Section Header',
                                    style: TextStyle(color: draft.yellow, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),

                                  // Body paragraph
                                  Text(
                                    'Quill & Papyrus AI provides local Markdown editing grounded in on-device AI. This live preview reflects your hex palette dynamically as you type.',
                                    style: TextStyle(color: draft.fg, fontSize: 12, height: 1.4),
                                  ),
                                  const SizedBox(height: 8),

                                  // Inline Code & Link
                                  Wrap(
                                    spacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: draft.bg1,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: draft.bg3),
                                        ),
                                        child: Text(
                                          '`inline_code_token`',
                                          style: TextStyle(color: draft.orange, fontSize: 11, fontFamily: 'monospace'),
                                        ),
                                      ),
                                      Text(
                                        '[[Internal Wikilink]]',
                                        style: TextStyle(color: draft.blue, fontSize: 12, decoration: TextDecoration.underline),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // GFM Blockquote
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                                    decoration: BoxDecoration(
                                      color: draft.bg1,
                                      border: Border(left: BorderSide(color: draft.accent, width: 3)),
                                      borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                                    ),
                                    child: Text(
                                      '> [!NOTE]\n> Real-time WCAG accessibility guidance is active.',
                                      style: TextStyle(color: draft.fg, fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // GFM Tags & Badges
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: draft.bg2,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: draft.bg3),
                                        ),
                                        child: Text('#journal', style: TextStyle(color: draft.accent, fontSize: 10)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: draft.bg2,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: draft.bg3),
                                        ),
                                        child: Text('@project', style: TextStyle(color: draft.purple, fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Inline Diff Preview
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: draft.additionBg,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: draft.green.withValues(alpha: 0.5)),
                                        ),
                                        child: Text('+ added proposal text', style: TextStyle(color: draft.green, fontSize: 10)),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: draft.deletionBg,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: draft.red.withValues(alpha: 0.5)),
                                        ),
                                        child: Text('- deleted draft text', style: TextStyle(color: draft.red, fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: draft.fgMuted)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: draft.accent,
                    foregroundColor: draft.bgHard,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final newTheme = _buildCurrentDraft();
                    await ref.read(themeProvider.notifier).saveCustomTheme(newTheme);
                    await ref.read(themeProvider.notifier).selectTheme(newTheme.id);
                    if (context.mounted) {
                      Navigator.pop(context, newTheme);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContrastGuide(AppThemeData draft, double fgRatio, double accentRatio) {
    final fgRating = AppThemeData.getContrastRating(fgRatio);
    final fgRatingColor = AppThemeData.getContrastRatingColor(fgRatio);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: draft.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: draft.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.accessibility_new, color: draft.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                'WCAG 2.1 CONTRAST GUIDE',
                style: TextStyle(color: draft.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Body Text on Background
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Text on Background:', style: TextStyle(color: draft.fg, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fgRatingColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: fgRatingColor),
                ),
                child: Text(
                  '${fgRatio.toStringAsFixed(1)}:1  •  $fgRating',
                  style: TextStyle(color: fgRatingColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Accent on Background
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Accent on Background:', style: TextStyle(color: draft.fgMuted, fontSize: 12)),
              Text(
                '${accentRatio.toStringAsFixed(1)}:1 (${AppThemeData.getContrastRating(accentRatio)})',
                style: TextStyle(
                  color: AppThemeData.getContrastRatingColor(accentRatio),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHexField(String label, TextEditingController ctrl, Color currentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          // Color indicator swatch
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            height: 32,
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#a-fA-F0-9]')),
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.cyan)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
