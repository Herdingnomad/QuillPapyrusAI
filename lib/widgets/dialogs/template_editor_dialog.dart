import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/document_template.dart';
import 'package:quill_papyrus_ai/providers/template_provider.dart';
import 'package:quill_papyrus_ai/providers/theme_provider.dart';
import 'package:uuid/uuid.dart';

Future<DocumentTemplate?> showTemplateEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  DocumentTemplate? initialTemplate,
}) async {
  return showDialog<DocumentTemplate>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => TemplateEditorDialog(initialTemplate: initialTemplate),
  );
}

class TemplateEditorDialog extends ConsumerStatefulWidget {
  final DocumentTemplate? initialTemplate;

  const TemplateEditorDialog({super.key, this.initialTemplate});

  @override
  ConsumerState<TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends ConsumerState<TemplateEditorDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _contentCtrl;
  String _selectedIcon = 'description';
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    final tmpl = widget.initialTemplate;
    _titleCtrl = TextEditingController(text: tmpl?.title ?? 'New Document Template');
    _descCtrl = TextEditingController(text: tmpl?.description ?? '');
    _categoryCtrl = TextEditingController(text: tmpl?.category ?? 'Custom');
    _contentCtrl = TextEditingController(
      text: tmpl?.content ??
          '''---
title: "{{title}}"
date: {{date}}
tags: [template]
topics: [general]
---

# {{title}}
**Created:** {{date}}

{{cursor}}
''',
    );
    _selectedIcon = tmpl?.icon ?? 'description';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _insertVariable(String token) {
    final text = _contentCtrl.text;
    final sel = _contentCtrl.selection;
    if (sel.isValid) {
      final start = sel.start;
      final end = sel.end;
      final newText = text.replaceRange(start, end, token);
      _contentCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + token.length),
      );
    } else {
      _contentCtrl.text += token;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final theme = themeState.activeTheme;
    final templateState = ref.watch(templateProvider);
    final screenSize = MediaQuery.of(context).size;
    final isShortHeight = screenSize.height < 520;
    final isVeryCompact = screenSize.width < 500;

    final horizontalPadding = isVeryCompact ? 8.0 : 16.0;
    final verticalPadding = isShortHeight ? 8.0 : 16.0;

    final dialogWidth = (screenSize.width - horizontalPadding * 2).clamp(280.0, 820.0);
    final dialogHeight = (screenSize.height - verticalPadding * 2).clamp(260.0, 700.0);

    return Dialog(
      backgroundColor: theme.bg1,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.bg3),
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: EdgeInsets.all(isShortHeight || isVeryCompact ? 10 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.edit_document, color: theme.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.initialTemplate != null ? 'Edit Document Template' : 'Create New Document Template',
                    style: TextStyle(color: theme.fg, fontSize: isVeryCompact ? 15 : 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.fgMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metadata Row: Title, Category, Icon
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _titleCtrl,
                    style: TextStyle(color: theme.fg, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Template Title',
                      labelStyle: TextStyle(color: theme.fgMuted, fontSize: 12),
                      filled: true,
                      fillColor: theme.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.bg3)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.accent)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _categoryCtrl,
                    style: TextStyle(color: theme.fg, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: theme.fgMuted, fontSize: 12),
                      filled: true,
                      fillColor: theme.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.bg3)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.accent)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description Row
            TextField(
              controller: _descCtrl,
              style: TextStyle(color: theme.fg, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Description / Purpose',
                labelStyle: TextStyle(color: theme.fgMuted, fontSize: 12),
                filled: true,
                fillColor: theme.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.bg3)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.accent)),
              ),
            ),
            const SizedBox(height: 12),

            // Variable Macro Insertion Helper Bar
            Row(
              children: [
                Text(
                  'Insert Macro:',
                  style: TextStyle(color: theme.accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _macroChip('{{date}} (Default)', '{{date}}', theme),
                        _macroChip('{{date_us}} (MM-DD-YYYY)', '{{date_us}}', theme),
                        _macroChip('{{date_iso}} (YYYY-MM-DD)', '{{date_iso}}', theme),
                        _macroChip('{{time}}', '{{time}}', theme),
                        _macroChip('{{datetime}}', '{{datetime}}', theme),
                        _macroChip('{{title}}', '{{title}}', theme),
                        _macroChip('{{cursor}} (Initial Focus)', '{{cursor}}', theme),
                        _macroChip('{{uuid}}', '{{uuid}}', theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle Preview button
                IconButton(
                  icon: Icon(_showPreview ? Icons.edit : Icons.remove_red_eye_outlined, color: theme.accent, size: 18),
                  tooltip: _showPreview ? 'Switch to Edit' : 'Preview Expanded',
                  onPressed: () {
                    setState(() => _showPreview = !_showPreview);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Editor / Preview Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.bg3),
                ),
                padding: const EdgeInsets.all(10),
                child: _showPreview
                    ? SingleChildScrollView(
                        child: Text(
                          DocumentTemplate(
                            id: 'preview',
                            title: _titleCtrl.text,
                            description: _descCtrl.text,
                            category: _categoryCtrl.text,
                            icon: _selectedIcon,
                            content: _contentCtrl.text,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ).applyVariables(dateFormat: templateState.dateFormat).content,
                          style: TextStyle(color: theme.fg, fontSize: 12, fontFamily: 'monospace'),
                        ),
                      )
                    : TextField(
                        controller: _contentCtrl,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(color: theme.fg, fontSize: 12, fontFamily: 'monospace', height: 1.4),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter Markdown template body...',
                          hintStyle: TextStyle(color: theme.fgMuted),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: theme.fgMuted)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.bgHard,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save Template', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final tmpl = DocumentTemplate(
                      id: widget.initialTemplate?.id ?? const Uuid().v4(),
                      title: _titleCtrl.text.trim().isEmpty ? 'Document Template' : _titleCtrl.text.trim(),
                      description: _descCtrl.text.trim(),
                      category: _categoryCtrl.text.trim().isEmpty ? 'Custom' : _categoryCtrl.text.trim(),
                      icon: _selectedIcon,
                      content: _contentCtrl.text,
                      isBuiltIn: false,
                      createdAt: widget.initialTemplate?.createdAt ?? now,
                      updatedAt: now,
                    );

                    if (widget.initialTemplate != null) {
                      await ref.read(templateProvider.notifier).updateTemplate(tmpl);
                    } else {
                      await ref.read(templateProvider.notifier).createTemplate(tmpl);
                    }

                    if (context.mounted) {
                      Navigator.pop(context, tmpl);
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

  Widget _macroChip(String label, String token, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        label: Text(label, style: TextStyle(color: theme.fg, fontSize: 10)),
        backgroundColor: theme.bg2,
        side: BorderSide(color: theme.bg3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onPressed: () => _insertVariable(token),
      ),
    );
  }
}
