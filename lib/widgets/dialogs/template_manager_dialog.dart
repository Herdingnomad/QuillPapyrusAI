import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/document_template.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/template_provider.dart';
import 'package:quill_papyrus_ai/providers/theme_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/template_editor_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/template_generator_dialog.dart';

Future<void> showTemplateManagerDialog(BuildContext context, WidgetRef ref) async {
  return showDialog(
    context: context,
    builder: (ctx) => const TemplateManagerDialog(),
  );
}

class TemplateManagerDialog extends ConsumerStatefulWidget {
  const TemplateManagerDialog({super.key});

  @override
  ConsumerState<TemplateManagerDialog> createState() => _TemplateManagerDialogState();
}

class _TemplateManagerDialogState extends ConsumerState<TemplateManagerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final theme = themeState.activeTheme;
    final templateState = ref.watch(templateProvider);
    final filtered = templateState.filteredTemplates;
    final activeTab = ref.watch(editorProvider).activeTab;

    return Dialog(
      backgroundColor: theme.bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.bg3),
      ),
      child: Container(
        width: 860,
        height: 680,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.style_outlined, color: theme.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document Template Library',
                        style: TextStyle(color: theme.fg, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Use, create, and manage Markdown document templates with automatic date and variable expansion.',
                        style: TextStyle(color: theme.fgMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Action: Save Current Note as Template
                if (activeTab != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.fg,
                      side: BorderSide(color: theme.bg3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 15),
                    label: const Text('Save Active Note as Template', style: TextStyle(fontSize: 12)),
                    onPressed: () => _promptSaveActiveNote(context, ref, activeTab.fileName, activeTab.content, theme),
                  ),
                  const SizedBox(width: 8),
                ],
                // Action: AI Generator
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.yellow,
                    side: BorderSide(color: theme.bg3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('AI Draft', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    Navigator.pop(context);
                    showTemplateGeneratorDialog(context, ref);
                  },
                ),
                const SizedBox(width: 8),
                // Action: Create New Template
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.bgHard,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => showTemplateEditorDialog(context, ref),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.close, color: theme.fgMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Controls Bar: Search + Date Format Preference Dropdown
            Row(
              children: [
                // Search Field
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: theme.fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search templates by title, tag, or content...',
                      hintStyle: TextStyle(color: theme.fgMuted, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: theme.fgMuted, size: 18),
                      filled: true,
                      fillColor: theme.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.bg3)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.bg3)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.accent)),
                    ),
                    onChanged: (val) {
                      ref.read(templateProvider.notifier).setSearchQuery(val);
                    },
                  ),
                ),
                const SizedBox(width: 14),

                // Date Format Preference Selector (US / ISO / EU)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.bg3),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: theme.accent),
                      const SizedBox(width: 6),
                      Text('Date Format:', style: TextStyle(color: theme.fgMuted, fontSize: 12)),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: templateState.dateFormat,
                        dropdownColor: theme.bg1,
                        underline: const SizedBox(),
                        style: TextStyle(color: theme.fg, fontSize: 12, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 'us', child: Text('U.S. (MM-DD-YYYY)')),
                          DropdownMenuItem(value: 'iso', child: Text('ISO (YYYY-MM-DD)')),
                          DropdownMenuItem(value: 'eu', child: Text('EU (DD-MM-YYYY)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(templateProvider.notifier).setDateFormat(val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: templateState.availableCategories.map((cat) {
                  final isSelected = templateState.selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: theme.accent,
                      backgroundColor: theme.bg,
                      labelStyle: TextStyle(
                        color: isSelected ? theme.bgHard : theme.fg,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(color: isSelected ? theme.accent : theme.bg3),
                      onSelected: (_) {
                        ref.read(templateProvider.notifier).setSelectedCategory(cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Templates Grid
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No templates match your search.',
                        style: TextStyle(color: theme.fgMuted, fontSize: 13),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.1,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final tmpl = filtered[idx];
                        return _buildTemplateCard(context, ref, tmpl, theme, activeTab != null);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context,
    WidgetRef ref,
    DocumentTemplate tmpl,
    dynamic theme,
    bool hasActiveEditor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Icon + Title + Category
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.bg1,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(_getIconData(tmpl.icon), color: theme.accent, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tmpl.title,
                      style: TextStyle(color: theme.fg, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      tmpl.category,
                      style: TextStyle(color: theme.fgMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (tmpl.isBuiltIn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.bg1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: theme.bg3),
                  ),
                  child: Text('Built-in', style: TextStyle(color: theme.fgMuted, fontSize: 10)),
                ),
            ],
          ),

          // Description
          Text(
            tmpl.description,
            style: TextStyle(color: theme.fg, fontSize: 12, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Use Template Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.bgHard,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Use Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _useTemplate(context, ref, tmpl),
              ),

              // CRUD buttons
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.copy, size: 14, color: theme.fgMuted),
                    tooltip: 'Duplicate Template',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => ref.read(templateProvider.notifier).duplicateTemplate(tmpl.id),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 15, color: theme.accent),
                    tooltip: 'Edit Template',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => showTemplateEditorDialog(context, ref, initialTemplate: tmpl),
                  ),
                  if (!tmpl.isBuiltIn) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 15, color: theme.red),
                      tooltip: 'Delete Template',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () => _showDeleteConfirm(context, ref, tmpl, theme),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _useTemplate(BuildContext context, WidgetRef ref, DocumentTemplate tmpl) {
    final activeTab = ref.read(editorProvider).activeTab;
    final workspaceState = ref.read(workspaceProvider);
    final dateFormat = ref.read(templateProvider).dateFormat;

    showModalBottomSheet(
      context: context,
      backgroundColor: ref.read(themeProvider).activeTheme.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        final theme = ref.read(themeProvider).activeTheme;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Use "${tmpl.title}"', style: TextStyle(color: theme.fg, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.note_add, color: theme.accent),
                title: Text('Create New File from Template', style: TextStyle(color: theme.fg, fontSize: 14)),
                subtitle: Text('Creates a new .md note in the active directory', style: TextStyle(color: theme.fgMuted, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  _createNewFileFromTemplate(context, ref, tmpl, dateFormat, workspaceState);
                },
              ),
              if (activeTab != null)
                ListTile(
                  leading: Icon(Icons.input, color: theme.yellow),
                  title: Text('Insert into Current Document', style: TextStyle(color: theme.fg, fontSize: 14)),
                  subtitle: Text('Appends expanded template into active editor tab', style: TextStyle(color: theme.fgMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    final result = tmpl.applyVariables(dateFormat: dateFormat);
                    final current = activeTab.content;
                    final merged = current.isEmpty ? result.content : '$current\n\n${result.content}';
                    ref.read(editorProvider.notifier).updateContent(merged);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createNewFileFromTemplate(
    BuildContext context,
    WidgetRef ref,
    DocumentTemplate tmpl,
    String dateFormat,
    dynamic workspaceState,
  ) async {
    final parentUri = workspaceState.fileTree?.uri ?? workspaceState.rootUri;
    if (parentUri == null) return;

    final now = DateTime.now();
    final dStr = (dateFormat == 'us')
        ? '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.year}'
        : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final cleanSlug = tmpl.title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), '-');
    final fileName = '$dStr-$cleanSlug.md';

    final expanded = tmpl.applyVariables(dateFormat: dateFormat, title: tmpl.title);

    final newUri = await ref.read(workspaceProvider.notifier).createFile(parentUri, fileName);
    if (newUri != null) {
      await ref.read(editorProvider.notifier).openFile(newUri, fileName);
      ref.read(editorProvider.notifier).updateContent(expanded.content);
      await ref.read(editorProvider.notifier).saveActiveFile();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created note "$fileName" from template!'),
            backgroundColor: ref.read(themeProvider).activeTheme.bg1,
          ),
        );
      }
    }
  }

  void _promptSaveActiveNote(
    BuildContext context,
    WidgetRef ref,
    String fileName,
    String content,
    dynamic theme,
  ) {
    final titleCtrl = TextEditingController(text: fileName.replaceAll('.md', ''));
    final descCtrl = TextEditingController(text: 'Custom template from $fileName');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bg1,
        title: Text('Save Active Note as Template', style: TextStyle(color: theme.fg, fontSize: 16)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: theme.fg, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Template Title',
                  labelStyle: TextStyle(color: theme.fgMuted),
                  filled: true,
                  fillColor: theme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                style: TextStyle(color: theme.fg, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: theme.fgMuted),
                  filled: true,
                  fillColor: theme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.fgMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.accent, foregroundColor: theme.bgHard),
            onPressed: () async {
              await ref.read(templateProvider.notifier).saveActiveDocumentAsTemplate(
                    title: titleCtrl.text,
                    content: content,
                    description: descCtrl.text,
                  );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: theme.bg1,
                    content: Text('Note saved to Template Library!', style: TextStyle(color: theme.green)),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, DocumentTemplate tmpl, dynamic theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bg1,
        title: Text('Delete Template?', style: TextStyle(color: theme.fg, fontSize: 16)),
        content: Text('Are you sure you want to delete "${tmpl.title}"?', style: TextStyle(color: theme.fgMuted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: theme.fgMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(templateProvider.notifier).deleteTemplate(tmpl.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String icon) {
    switch (icon) {
      case 'coffee':
        return Icons.coffee;
      case 'rocket':
        return Icons.rocket_launch;
      case 'groups':
        return Icons.groups;
      case 'analytics':
        return Icons.analytics;
      case 'agriculture':
        return Icons.agriculture;
      case 'science':
        return Icons.science;
      case 'description':
      default:
        return Icons.description;
    }
  }
}
