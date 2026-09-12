import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/app_theme_data.dart';
import 'package:quill_papyrus_ai/providers/theme_provider.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/theme_editor_dialog.dart';

Future<void> showThemeManagerDialog(BuildContext context, WidgetRef ref) async {
  return showDialog(
    context: context,
    builder: (ctx) => const ThemeManagerDialog(),
  );
}

class ThemeManagerDialog extends ConsumerWidget {
  const ThemeManagerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final activeTheme = themeState.activeTheme;
    final allThemes = themeState.allThemes;

    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 700;

    return Dialog(
      backgroundColor: activeTheme.bg1,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 24,
        vertical: isCompact ? 14 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: activeTheme.bg3),
      ),
      child: Container(
        width: isCompact ? double.infinity : (screenSize.width * 0.94).clamp(500.0, 800.0),
        height: isCompact ? screenSize.height * 0.92 : (screenSize.height * 0.88).clamp(520.0, 640.0),
        padding: EdgeInsets.all(isCompact ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.palette_outlined, color: activeTheme.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Color Theme Manager',
                        style: TextStyle(
                          color: activeTheme.fg,
                          fontSize: isCompact ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isCompact)
                        Text(
                          'Choose a theme, create your own with custom hex codes, or duplicate an existing preset.',
                          style: TextStyle(color: activeTheme.fgMuted, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (!isCompact) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeTheme.accent,
                      foregroundColor: activeTheme.bgHard,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create New Theme'),
                    onPressed: () => showThemeEditorDialog(context, ref),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: Icon(Icons.close, color: activeTheme.fgMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Action Bar: Create Theme (on compact), Import / Export JSON
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (isCompact)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeTheme.accent,
                      foregroundColor: activeTheme.bgHard,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('New Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => showThemeEditorDialog(context, ref),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: activeTheme.fg,
                    side: BorderSide(color: activeTheme.bg3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('Import (JSON)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _showImportDialog(context, ref, activeTheme),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: activeTheme.fg,
                    side: BorderSide(color: activeTheme.bg3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  icon: const Icon(Icons.upload, size: 14),
                  label: const Text('Export Active (JSON)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final json = ref.read(themeProvider.notifier).exportThemeToJson(activeTheme);
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: activeTheme.bg1,
                        content: Text(
                          'Theme JSON copied to clipboard!',
                          style: TextStyle(color: activeTheme.green),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Themes Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isCompact ? 1 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isCompact ? 2.3 : 2.2,
                ),
                itemCount: allThemes.length,
                itemBuilder: (ctx, index) {
                  final theme = allThemes[index];
                  final isActive = theme.id == activeTheme.id;

                  return _buildThemeCard(context, ref, theme, isActive, activeTheme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    WidgetRef ref,
    AppThemeData theme,
    bool isActive,
    AppThemeData currentAppTheme,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        ref.read(themeProvider.notifier).selectTheme(theme.id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? theme.accent : currentAppTheme.bg3,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title + Badge Row
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        theme.name,
                        style: TextStyle(
                          color: theme.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (theme.isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.bg2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Custom',
                            style: TextStyle(color: theme.accent, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: theme.bgHard,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            // Color Swatches Row
            Row(
              children: [
                _colorSwatch(theme.bgHard),
                _colorSwatch(theme.bg),
                _colorSwatch(theme.bg1),
                _colorSwatch(theme.fg),
                _colorSwatch(theme.accent),
                _colorSwatch(theme.accentSecondary),
                _colorSwatch(theme.red),
                _colorSwatch(theme.green),
                _colorSwatch(theme.yellow),
                _colorSwatch(theme.blue),
              ],
            ),

            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Duplicate button
                IconButton(
                  icon: Icon(Icons.copy, size: 15, color: theme.fgMuted),
                  tooltip: 'Duplicate & Edit',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () async {
                    final cloned = await ref.read(themeProvider.notifier).duplicateTheme(theme.id);
                    if (context.mounted) {
                      showThemeEditorDialog(context, ref, initialTheme: cloned);
                    }
                  },
                ),
                if (theme.isCustom) ...[
                  const SizedBox(width: 4),
                  // Edit custom theme
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 16, color: theme.accent),
                    tooltip: 'Edit Custom Theme',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => showThemeEditorDialog(context, ref, initialTheme: theme),
                  ),
                  const SizedBox(width: 4),
                  // Delete custom theme
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 16, color: theme.red),
                    tooltip: 'Delete Theme',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () {
                      _showDeleteConfirm(context, ref, theme);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSwatch(Color color) {
    return Expanded(
      child: Container(
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, AppThemeData theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bg1,
        title: Text('Delete Theme?', style: TextStyle(color: theme.fg, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete "${theme.name}"?',
          style: TextStyle(color: theme.fgMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.fgMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(themeProvider.notifier).deleteCustomTheme(theme.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref, AppThemeData currentTheme) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: currentTheme.bg1,
        title: Text('Import Theme from JSON', style: TextStyle(color: currentTheme.fg, fontSize: 16)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste your theme JSON configuration below:',
                style: TextStyle(color: currentTheme.fgMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 6,
                style: TextStyle(color: currentTheme.fg, fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: currentTheme.bg,
                  hintText: '{"name": "My Theme", "colors": {...}}',
                  hintStyle: TextStyle(color: currentTheme.fgMuted, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: currentTheme.bg3)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: currentTheme.fgMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: currentTheme.accent, foregroundColor: currentTheme.bgHard),
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                final success = await ref.read(themeProvider.notifier).importThemeFromJson(text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: currentTheme.bg1,
                      content: Text(
                        success ? 'Theme imported successfully!' : 'Failed to parse theme JSON.',
                        style: TextStyle(color: success ? currentTheme.green : currentTheme.red),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}
