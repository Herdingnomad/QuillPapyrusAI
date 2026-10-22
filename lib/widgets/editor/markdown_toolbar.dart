import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/diff_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/services/frontmatter_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/providers/theme_provider.dart';
import 'package:quill_papyrus_ai/services/themed_export_service.dart';
import 'package:quill_papyrus_ai/services/typography_service.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/compiler_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/snapshot_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/snippet_inserter_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/template_generator_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/template_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/theme_manager_dialog.dart';

class MarkdownToolbar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final UndoHistoryController? undoController;
  final VoidCallback? onSave;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    this.undoController,
    this.onSave,
  });

  @override
  ConsumerState<MarkdownToolbar> createState() => _MarkdownToolbarState();
}

class _MarkdownToolbarState extends ConsumerState<MarkdownToolbar> {
  bool _isExpanded = false;
  bool _isAiLoading = false;
  bool _insertDirectly = false;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateSelection);
  }

  @override
  void didUpdateWidget(covariant MarkdownToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateSelection);
      widget.controller.addListener(_updateSelection);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateSelection);
    super.dispose();
  }

  void _updateSelection() {
    final sel = widget.controller.selection;
    if (sel.isValid && !sel.isCollapsed) {
      _lastSelection = sel;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isExpanded) {
      // Multi-row expanded layout
      return Container(
        color: GruvboxColors.bg1,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 2.0,
                    runSpacing: 2.0,
                    children: _buildAllToolButtons(context),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.expand_less, color: GruvboxColors.aqua, size: 20),
                  tooltip: 'Collapse Toolbar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    setState(() {
                      _isExpanded = false;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Single-row horizontally scrollable layout
    return Container(
      height: 38,
      color: GruvboxColors.bg1,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              children: _buildAllToolButtons(context),
            ),
          ),
          // Toggle between single scrollable row and multi-row wrap
          IconButton(
            icon: Icon(Icons.expand_more, color: GruvboxColors.gray, size: 20),
            tooltip: 'Expand All Tools (Multi-Row)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() {
                _isExpanded = true;
              });
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAllToolButtons(BuildContext context) {
    final activeTab = ref.watch(editorProvider).activeTab;
    final isDirty = activeTab?.isDirty ?? false;
    final canUndo = activeTab?.canUndo == true || (widget.undoController?.value.canUndo ?? false);
    final canRedo = activeTab?.canRedo == true || (widget.undoController?.value.canRedo ?? false);

    return [
      if (widget.onSave != null) ...[
        IconButton(
          icon: Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(
                isDirty ? Icons.save : Icons.save_outlined,
                size: 18,
                color: isDirty ? GruvboxColors.orange : (activeTab != null ? GruvboxColors.fg4 : GruvboxColors.bg3),
              ),
              if (isDirty)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: GruvboxColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          tooltip: isDirty ? 'Save * (Ctrl+S)' : 'Saved (Ctrl+S)',
          padding: const EdgeInsets.symmetric(horizontal: 4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: widget.onSave!,
        ),
      ],
      // Undo Button
      _ToolbarButton(
        icon: Icons.undo,
        tooltip: 'Undo (Ctrl+Z)',
        iconColor: canUndo ? GruvboxColors.yellow : GruvboxColors.gray,
        onPressed: () {
          if (widget.undoController != null && widget.undoController!.value.canUndo) {
            widget.undoController!.undo();
          } else {
            ref.read(editorProvider.notifier).undo();
          }
        },
      ),
      // Redo Button
      _ToolbarButton(
        icon: Icons.redo,
        tooltip: 'Redo (Ctrl+Y)',
        iconColor: canRedo ? GruvboxColors.yellow : GruvboxColors.gray,
        onPressed: () {
          if (widget.undoController != null && widget.undoController!.value.canRedo) {
            widget.undoController!.redo();
          } else {
            ref.read(editorProvider.notifier).redo();
          }
        },
      ),
      _Divider(),
      // AI Action Trigger Menu
      _buildAiMenuButton(context),
      _Divider(),
      // Grouped Dropdown Menus
      _buildFormatDropdown(context),
      _buildListsDropdown(context),
      _buildInsertDropdown(context),
      _buildPublishDropdown(context),
    ];
  }

  Widget _buildToolbarMenuButton<T>({
    required IconData icon,
    required String label,
    required String tooltip,
    Color? iconColor,
    required ValueChanged<T> onSelected,
    required List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder,
  }) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      color: GruvboxColors.bg1,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: GruvboxColors.bg3),
      ),
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: GruvboxColors.bg,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: GruvboxColors.bg3.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor ?? GruvboxColors.fg2),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: GruvboxColors.fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 13, color: GruvboxColors.gray),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatDropdown(BuildContext context) {
    return _buildToolbarMenuButton<String>(
      icon: Icons.text_format,
      label: 'Format',
      tooltip: 'Text Styling & Typography',
      onSelected: (val) {
        switch (val) {
          case 'bold':
            _wrapSelection('**', '**');
            break;
          case 'italic':
            _wrapSelection('*', '*');
            break;
          case 'heading':
            _cycleHeading();
            break;
          case 'inline_code':
            _wrapSelection('`', '`');
            break;
          case 'blockquote':
            _prefixLine('> ');
            break;
          case 'hr':
            _insertText('\n---\n');
            break;
          case 'scene_divider':
            _insertSceneDivider();
            break;
          case 'smart_typography':
            _applySmartPunctuation();
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'bold',
          child: Row(
            children: [
              Icon(Icons.format_bold, size: 16, color: GruvboxColors.fg),
              const SizedBox(width: 8),
              Expanded(child: Text('Bold (**text**)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
              Text('Ctrl+B', style: TextStyle(color: GruvboxColors.gray, fontSize: 11)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'italic',
          child: Row(
            children: [
              Icon(Icons.format_italic, size: 16, color: GruvboxColors.fg),
              const SizedBox(width: 8),
              Expanded(child: Text('Italic (*text*)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
              Text('Ctrl+I', style: TextStyle(color: GruvboxColors.gray, fontSize: 11)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'heading',
          child: Row(
            children: [
              Icon(Icons.title, size: 16, color: GruvboxColors.yellow),
              const SizedBox(width: 8),
              Expanded(child: Text('Cycle Heading (# H1–H6)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'inline_code',
          child: Row(
            children: [
              Icon(Icons.code, size: 16, color: GruvboxColors.aqua),
              const SizedBox(width: 8),
              Expanded(child: Text('Inline Code (`code`)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'blockquote',
          child: Row(
            children: [
              Icon(Icons.format_quote, size: 16, color: GruvboxColors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('Blockquote (> quote)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'hr',
          child: Row(
            children: [
              Icon(Icons.horizontal_rule, size: 16, color: GruvboxColors.gray),
              const SizedBox(width: 8),
              Expanded(child: Text('Horizontal Rule (---)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'scene_divider',
          child: Row(
            children: [
              Icon(Icons.more_horiz, size: 16, color: GruvboxColors.yellow),
              const SizedBox(width: 8),
              Expanded(child: Text('Scene Divider (* * *)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'smart_typography',
          child: Row(
            children: [
              Icon(Icons.auto_fix_high, size: 16, color: GruvboxColors.aqua),
              const SizedBox(width: 8),
              Expanded(child: Text('Smart Typography (Quotes/Dashes)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListsDropdown(BuildContext context) {
    return _buildToolbarMenuButton<String>(
      icon: Icons.format_list_bulleted,
      label: 'Lists',
      tooltip: 'Bulleted, Numbered & Task Lists',
      onSelected: (val) {
        switch (val) {
          case 'bullet':
            _prefixLine('- ');
            break;
          case 'numbered':
            _prefixLine('1. ');
            break;
          case 'task':
            _prefixLine('- [ ] ');
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'bullet',
          child: Row(
            children: [
              Icon(Icons.format_list_bulleted, size: 16, color: GruvboxColors.aqua),
              const SizedBox(width: 8),
              Expanded(child: Text('Bulleted List (- )', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'numbered',
          child: Row(
            children: [
              Icon(Icons.format_list_numbered, size: 16, color: GruvboxColors.yellow),
              const SizedBox(width: 8),
              Expanded(child: Text('Numbered List (1. )', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'task',
          child: Row(
            children: [
              Icon(Icons.checklist, size: 16, color: GruvboxColors.green),
              const SizedBox(width: 8),
              Expanded(child: Text('Task List (- [ ] )', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsertDropdown(BuildContext context) {
    return _buildToolbarMenuButton<String>(
      icon: Icons.add_circle_outline,
      label: 'Insert',
      tooltip: 'Links, Media, Tables, Snippets & Templates',
      onSelected: (val) {
        switch (val) {
          case 'link':
            _wrapSelection('[', '](url)');
            break;
          case 'image':
            _wrapSelection('![alt](', ')');
            break;
          case 'table':
            _insertTable();
            break;
          case 'code_block':
            _insertCodeBlock();
            break;
          case 'frontmatter':
            _showFrontMatterDialog(context);
            break;
          case 'snippets':
            showSnippetInserterDialog(context, ref);
            break;
          case 'templates':
            showTemplateManagerDialog(context, ref);
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'link',
          child: Row(
            children: [
              Icon(Icons.link, size: 16, color: GruvboxColors.aqua),
              const SizedBox(width: 8),
              Expanded(child: Text('Hyperlink ([text](url))', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              Icon(Icons.image, size: 16, color: GruvboxColors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('Image (![alt](url))', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'table',
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, size: 16, color: GruvboxColors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text('Markdown Table (3x3)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'code_block',
          child: Row(
            children: [
              Icon(Icons.integration_instructions, size: 16, color: GruvboxColors.yellow),
              const SizedBox(width: 8),
              Expanded(child: Text('Code Block (```)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'frontmatter',
          child: Row(
            children: [
              Icon(Icons.post_add, size: 16, color: GruvboxColors.aqua),
              const SizedBox(width: 8),
              Expanded(child: Text('YAML Frontmatter', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'snippets',
          child: Row(
            children: [
              Icon(Icons.dashboard_customize_outlined, size: 16, color: GruvboxColors.purple),
              const SizedBox(width: 8),
              Expanded(child: Text('Snippets & Callouts', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'templates',
          child: Row(
            children: [
              Icon(Icons.style_outlined, size: 16, color: GruvboxColors.green),
              const SizedBox(width: 8),
              Expanded(child: Text('Document Templates', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPublishDropdown(BuildContext context) {
    return _buildToolbarMenuButton<String>(
      icon: Icons.publish,
      label: 'Publish',
      tooltip: 'Compile, Snapshots, Export & Themes',
      onSelected: (val) {
        switch (val) {
          case 'compile':
            CompilerDialog.show(context);
            break;
          case 'snapshots':
            _openSnapshots(context);
            break;
          case 'html':
            _handleThemedExport(context);
            break;
          case 'themes':
            showThemeManagerDialog(context, ref);
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'compile',
          child: Row(
            children: [
              Icon(Icons.print_outlined, size: 16, color: GruvboxColors.purple),
              const SizedBox(width: 8),
              Expanded(child: Text('Compile Manuscript (EPUB/PDF/DOCX)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'snapshots',
          child: Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 16, color: GruvboxColors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text('Scene Snapshots (Ctrl+Shift+S)', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'html',
          child: Row(
            children: [
              Icon(Icons.html_outlined, size: 16, color: GruvboxColors.aqua),
              const SizedBox(width: 8),
              Expanded(child: Text('Export Themed HTML', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'themes',
          child: Row(
            children: [
              Icon(Icons.palette_outlined, size: 16, color: GruvboxColors.yellow),
              const SizedBox(width: 8),
              Expanded(child: Text('Color Themes & Hex Builder', style: TextStyle(color: GruvboxColors.fg, fontSize: 12.5))),
            ],
          ),
        ),
      ],
    );
  }

  void _applySmartPunctuation() {
    final text = widget.controller.text;
    final converted = TypographyService.instance.applySmartTypography(text);
    if (converted != text) {
      widget.controller.text = converted;
      ref.read(editorProvider.notifier).updateContent(converted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          content: Text('Applied smart quotes and typography', style: TextStyle(color: GruvboxColors.aqua)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _insertSceneDivider() {
    _insertText('\n\n* * *\n\n');
  }

  void _openSnapshots(BuildContext context) {
    final activeTab = ref.read(editorProvider).activeTab;
    if (activeTab != null) {
      SnapshotManagerDialog.show(
        context,
        fileUri: activeTab.uri,
        fileName: activeTab.fileName,
        currentContent: widget.controller.text,
      );
    }
  }

  Widget _buildAiMenuButton(BuildContext context) {
    if (_isAiLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: GruvboxColors.bg,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: GruvboxColors.bg3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: GruvboxColors.aqua),
            ),
            const SizedBox(width: 6),
            Text('Thinking...', style: TextStyle(color: GruvboxColors.aqua, fontSize: 11)),
          ],
        ),
      );
    }

    return _buildToolbarMenuButton<String>(
      icon: Icons.auto_awesome,
      iconColor: GruvboxColors.yellow,
      label: 'AI Copilot',
      tooltip: 'AI Writing Assistance & Copilot',
      onSelected: (action) => _handleAiAction(context, action),
      itemBuilder: (ctx) => [
        CheckedPopupMenuItem<String>(
          value: 'toggle_insert_mode',
          checked: _insertDirectly,
          child: Row(
            children: [
              Icon(
                _insertDirectly ? Icons.subdirectory_arrow_right : Icons.difference_outlined,
                color: _insertDirectly ? GruvboxColors.aqua : GruvboxColors.gray,
                size: 15,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _insertDirectly ? 'Direct Insert (No Diff)' : 'Direct Insert Mode',
                  style: TextStyle(
                    color: _insertDirectly ? GruvboxColors.aqua : GruvboxColors.fg,
                    fontSize: 12,
                    fontWeight: _insertDirectly ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'grammar',
          child: Row(
            children: [
              Icon(Icons.spellcheck, color: GruvboxColors.aqua, size: 16),
              const SizedBox(width: 8),
              Text('Fix Grammar & Phrasing', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'expand',
          child: Row(
            children: [
              Icon(Icons.unfold_more, color: GruvboxColors.blue, size: 16),
              const SizedBox(width: 8),
              Text('Deepen & Expand', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'summarize',
          child: Row(
            children: [
              Icon(Icons.notes, color: GruvboxColors.green, size: 16),
              const SizedBox(width: 8),
              Text('Summarize to Bullets', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'action_items',
          child: Row(
            children: [
              Icon(Icons.checklist, color: GruvboxColors.orange, size: 16),
              const SizedBox(width: 8),
              Text('Extract Action Items', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'explain',
          child: Row(
            children: [
              Icon(Icons.school_outlined, color: GruvboxColors.purple, size: 16),
              const SizedBox(width: 8),
              Text('Explain & Simplify', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'table',
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, color: GruvboxColors.yellow, size: 16),
              SizedBox(width: 8),
              Text('Convert to Table', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'outline',
          child: Row(
            children: [
              Icon(Icons.format_list_numbered, color: GruvboxColors.darkAqua, size: 16),
              SizedBox(width: 8),
              Text('Generate Outline', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'concise',
          child: Row(
            children: [
              Icon(Icons.compress, color: GruvboxColors.darkOrange, size: 16),
              SizedBox(width: 8),
              Text('Make Concise', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'frontmatter',
          child: Row(
            children: [
              Icon(Icons.badge_outlined, color: GruvboxColors.aqua, size: 16),
              SizedBox(width: 8),
              Text('Generate Frontmatter with AI', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'template',
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: GruvboxColors.yellow, size: 16),
              SizedBox(width: 8),
              Text('Generate Template with AI...', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAiAction(BuildContext context, String action) async {
    if (action == 'toggle_insert_mode') {
      setState(() {
        _insertDirectly = !_insertDirectly;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            duration: const Duration(seconds: 2),
            content: Text(
              _insertDirectly
                  ? 'Direct Insert Mode enabled: AI generations will be inserted directly into the document'
                  : 'Diff Review Mode enabled: AI generations will show inline diff for review',
              style: TextStyle(color: GruvboxColors.aqua),
            ),
          ),
        );
      }
      return;
    }
    if (action == 'template') {
      showTemplateManagerDialog(context, ref);
      return;
    }
    if (action == 'frontmatter') {
      await _handleAiFrontmatter(context);
      return;
    }

    final text = widget.controller.text;
    var selection = widget.controller.selection;

    // Use cached selection if current selection collapsed when tapping popup menu
    if (!selection.isValid || selection.isCollapsed) {
      if (_lastSelection.isValid && !_lastSelection.isCollapsed && _lastSelection.end <= text.length) {
        selection = _lastSelection;
      }
    }

    int start = 0;
    int end = text.length;
    String targetText = text;
    bool isSelection = false;

    if (selection.isValid && !selection.isCollapsed) {
      start = selection.start.clamp(0, text.length);
      end = selection.end.clamp(start, text.length);
      if (start < end) {
        targetText = text.substring(start, end);
        isSelection = true;
      }
    }

    if (targetText.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            duration: Duration(seconds: 2),
            content: Text('Document is empty. Type some text to run AI actions.', style: TextStyle(color: GruvboxColors.yellow)),
          ),
        );
      }
      return;
    }

    setState(() {
      _isAiLoading = true;
    });

    final titleMap = {
      'grammar': 'Fix Grammar & Phrasing',
      'expand': 'Deepen & Expand',
      'summarize': 'Summarize to Bullets',
      'action_items': 'Extract Action Items',
      'explain': 'Explain & Simplify',
      'table': 'Convert to Table',
      'outline': 'Generate Outline',
      'concise': 'Make Concise',
    };
    final actionTitle = titleMap[action] ?? 'AI Edit';

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          duration: const Duration(seconds: 2),
          content: Text(
            'Running $actionTitle on ${isSelection ? "selected text" : "entire document"}...',
            style: TextStyle(color: GruvboxColors.aqua),
          ),
        ),
      );
    }

    try {
      final aiService = ref.read(aiServiceProvider);
      final aiConfig = ref.read(aiProvider).config;
      final activeTab = ref.read(editorProvider).activeTab;

      final result = await aiService.generateQuickEdit(
        action: action,
        selectedText: targetText,
        surroundingContext: text,
        config: aiConfig,
        currentDocUri: activeTab?.uri,
      );

      final cleanResult = DiffService.extractCleanAiContent(result);
      final finalContent = cleanResult.isNotEmpty ? cleanResult : result;

      if (_insertDirectly) {
        final insertPos = end.clamp(0, text.length);
        final needsNewline = insertPos > 0 && !text.substring(0, insertPos).endsWith('\n');
        final prefix = needsNewline ? '\n\n' : '\n';
        final insertion = '$prefix$finalContent\n';
        final updated = text.replaceRange(insertPos, insertPos, insertion);
        ref.read(editorProvider.notifier).updateContent(updated);
        widget.controller.text = updated;
        widget.controller.selection = TextSelection.collapsed(offset: insertPos + insertion.length);

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GruvboxColors.bg1,
              duration: const Duration(seconds: 2),
              content: Text(
                'Inserted $actionTitle below ${isSelection ? "selection" : "content"}',
                style: TextStyle(color: GruvboxColors.aqua),
              ),
            ),
          );
        }
      } else {
        final proposal = DiffService.createProposal(
          originalFullText: text,
          proposedReplacement: finalContent,
          selectionStart: start,
          selectionEnd: end,
          actionTitle: '$actionTitle (${isSelection ? "Selection" : "Full Document"})',
        );

        ref.read(diffProvider.notifier).showProposal(proposal);

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GruvboxColors.bg1,
              duration: const Duration(seconds: 3),
              content: Text(
                'Proposed $actionTitle — Tap Accept, Reject, or Insert Below',
                style: TextStyle(color: GruvboxColors.green),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            duration: const Duration(seconds: 2),
            content: Text(
              'Failed to generate $actionTitle. Please ensure model is loaded.',
              style: TextStyle(color: GruvboxColors.red),
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  Future<void> _handleAiFrontmatter(BuildContext context) async {
    final activeTab = ref.read(editorProvider).activeTab;
    if (activeTab == null) return;

    setState(() => _isAiLoading = true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          duration: Duration(seconds: 2),
          content: Text('Analyzing document to generate YAML Frontmatter...', style: TextStyle(color: GruvboxColors.aqua)),
        ),
      );
    }

    try {
      final aiService = ref.read(aiServiceProvider);
      final aiConfig = ref.read(aiProvider).config;
      final workspaceState = ref.read(workspaceProvider);
      final inferred = await aiService.generateFrontMatterForDocument(
        documentContent: activeTab.content,
        fallbackTitle: activeTab.fileName,
        workspaceTags: workspaceState.tags,
        workspaceTopics: workspaceState.topics,
        config: aiConfig,
      );

      final existingFmMatch = RegExp(r'^---\r?\n[\s\S]*?\r?\n---(?:\r?\n)?').firstMatch(activeTab.content);
      final fmEnd = existingFmMatch?.end ?? 0;
      final frontMatterStr = FrontMatterService.generateFullFrontMatter(
        title: inferred.title,
        date: inferred.date,
        dayOfWeek: inferred.dayOfWeek,
        mood: inferred.mood ?? '',
        tags: inferred.tags,
        topics: inferred.topics,
        status: inferred.status ?? '',
      );
      final replacement = existingFmMatch != null ? '$frontMatterStr\n' : '$frontMatterStr\n\n';

      if (_insertDirectly) {
        final updated = activeTab.content.replaceRange(0, fmEnd, replacement);
        ref.read(editorProvider.notifier).updateContent(updated);
        widget.controller.text = updated;

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GruvboxColors.bg1,
              duration: Duration(seconds: 2),
              content: Text(
                'Inserted AI Generated Frontmatter at line 1',
                style: TextStyle(color: GruvboxColors.aqua),
              ),
            ),
          );
        }
      } else {
        final proposal = DiffService.createProposal(
          originalFullText: activeTab.content,
          proposedReplacement: replacement,
          selectionStart: 0,
          selectionEnd: fmEnd,
          actionTitle: 'AI Generated Frontmatter',
        );

        ref.read(diffProvider.notifier).showProposal(proposal);

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: GruvboxColors.bg1,
              duration: Duration(seconds: 3),
              content: Text(
                'Proposed Frontmatter — Tap Accept, Reject, or Insert Below',
                style: TextStyle(color: GruvboxColors.green),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            content: Text('Failed to generate frontmatter.', style: TextStyle(color: GruvboxColors.red)),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isAiLoading = false);
    }
  }

  void _wrapSelection(String prefix, String suffix) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');

      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length + selectedText.length),
      );
    } else {
      final offset = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(offset, offset, '$prefix$suffix');

      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + prefix.length),
      );
    }
  }

  void _prefixLine(String prefix) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    int lineStart = offset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final newText = text.replaceRange(lineStart, lineStart, prefix);

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + prefix.length),
    );
  }

  void _cycleHeading() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    int lineStart = offset;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final currentLine = text.substring(lineStart);
    if (currentLine.startsWith('### ')) {
      final newText = text.replaceRange(lineStart, lineStart + 4, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: (offset - 4).clamp(0, newText.length)),
      );
    } else if (currentLine.startsWith('## ')) {
      final newText = text.replaceRange(lineStart, lineStart + 3, '### ');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 1),
      );
    } else if (currentLine.startsWith('# ')) {
      final newText = text.replaceRange(lineStart, lineStart + 2, '## ');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 1),
      );
    } else {
      final newText = text.replaceRange(lineStart, lineStart, '# ');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + 2),
      );
    }
  }

  void _insertCodeBlock() {
    _insertText('\n```\n\n```\n');
  }

  void _insertTable() {
    _insertText('\n| Column 1 | Column 2 |\n|---|---|\n| Item 1 | Item 2 |\n');
  }

  void _insertText(String insert) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final offset = selection.isValid ? selection.start : text.length;

    final newText = text.replaceRange(offset, offset, insert);

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + insert.length),
    );
  }

  void _showFrontMatterDialog(BuildContext context) {
    final activeTab = ref.read(editorProvider).activeTab;
    if (activeTab == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          content: Text('Open a document to insert frontmatter.', style: TextStyle(color: GruvboxColors.yellow)),
        ),
      );
      return;
    }

    final existing = FrontMatterService.parse(activeTab.content);
    final now = DateTime.now();
    final dStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final defaultDow = weekdays[now.weekday - 1];

    final defaultTitle = activeTab.fileName.endsWith('.md')
        ? activeTab.fileName.substring(0, activeTab.fileName.length - 3)
        : activeTab.fileName;

    final titleController = TextEditingController(text: existing?.title ?? defaultTitle);
    final dateController = TextEditingController(
      text: existing?.date != null
          ? "${existing!.date!.year.toString().padLeft(4, '0')}-${existing.date!.month.toString().padLeft(2, '0')}-${existing.date!.day.toString().padLeft(2, '0')}"
          : dStr,
    );
    final dayOfWeekController = TextEditingController(text: existing?.dayOfWeek ?? defaultDow);
    final moodController = TextEditingController(text: existing?.mood ?? '');
    final tagsController = TextEditingController(
      text: existing != null && existing.tags.isNotEmpty
          ? existing.tags.join(', ')
          : '',
    );
    final topicsController = TextEditingController(
      text: existing != null && existing.topics.isNotEmpty
          ? existing.topics.join(', ')
          : '',
    );
    final statusController = TextEditingController(
      text: existing?.status ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isDetecting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: GruvboxColors.bg1,
              title: Row(
                children: [
                  Icon(Icons.post_add, color: GruvboxColors.aqua, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Insert YAML Frontmatter', style: TextStyle(color: GruvboxColors.fg, fontSize: 16)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GruvboxColors.yellow,
                      side: BorderSide(color: GruvboxColors.yellow),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: isDetecting
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: GruvboxColors.yellow),
                          )
                        : Icon(Icons.auto_awesome, size: 14, color: GruvboxColors.yellow),
                    label: const Text('Auto-Detect with AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: isDetecting
                        ? null
                        : () async {
                            setModalState(() => isDetecting = true);
                            try {
                              final aiService = ref.read(aiServiceProvider);
                              final aiConfig = ref.read(aiProvider).config;
                              final workspaceState = ref.read(workspaceProvider);
                              final inferred = await aiService.generateFrontMatterForDocument(
                                documentContent: activeTab.content,
                                fallbackTitle: activeTab.fileName,
                                workspaceTags: workspaceState.tags,
                                workspaceTopics: workspaceState.topics,
                                config: aiConfig,
                              );
                              titleController.text = inferred.title ?? titleController.text;
                              if (inferred.date != null) {
                                dateController.text =
                                    "${inferred.date!.year.toString().padLeft(4, '0')}-${inferred.date!.month.toString().padLeft(2, '0')}-${inferred.date!.day.toString().padLeft(2, '0')}";
                              }
                              dayOfWeekController.text = inferred.dayOfWeek ?? dayOfWeekController.text;
                              moodController.text = inferred.mood ?? moodController.text;
                              if (inferred.tags.isNotEmpty) {
                                tagsController.text = inferred.tags.join(', ');
                              }
                              if (inferred.topics.isNotEmpty) {
                                topicsController.text = inferred.topics.join(', ');
                              }
                              statusController.text = inferred.status ?? statusController.text;
                            } catch (_) {}
                            setModalState(() => isDetecting = false);
                          },
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFrontMatterField('Title', titleController, hint: 'Document title'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildFrontMatterField('Date', dateController, hint: 'YYYY-MM-DD')),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFrontMatterField('Day of Week', dayOfWeekController, hint: 'Saturday')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFrontMatterField('Mood', moodController, hint: 'Reflective / Productive'),
                    const SizedBox(height: 8),
                    _buildFrontMatterField('Tags (comma separated)', tagsController, hint: 'journaling, technology, ...'),
                    const SizedBox(height: 8),
                    _buildFrontMatterField('Topics (comma separated)', topicsController, hint: 'writing, hardware, ...'),
                    const SizedBox(height: 8),
                    _buildFrontMatterField('Status', statusController, hint: "complete # Or 'in_progress'"),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: Icon(Icons.description_outlined, size: 14, color: GruvboxColors.blue),
                  label: Text('Templates...', style: TextStyle(color: GruvboxColors.blue, fontSize: 12)),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    showTemplateGeneratorDialog(context, ref);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GruvboxColors.aqua,
                    foregroundColor: GruvboxColors.bgHard,
                  ),
                  onPressed: () {
                    final tags = tagsController.text
                        .split(',')
                        .map((e) => e.trim().replaceAll('#', ''))
                        .where((e) => e.isNotEmpty)
                        .toList();
                    final topics = topicsController.text
                        .split(',')
                        .map((e) => e.trim().replaceAll('@', ''))
                        .where((e) => e.isNotEmpty)
                        .toList();

                    DateTime? parsedDate = DateTime.tryParse(dateController.text.trim());

                    ref.read(editorProvider.notifier).insertFrontMatterInActiveFile(
                          title: titleController.text.trim(),
                          date: parsedDate,
                          dayOfWeek: dayOfWeekController.text.trim(),
                          mood: moodController.text.trim(),
                          tags: tags,
                          topics: topics,
                          status: statusController.text.trim(),
                        );

                    Navigator.pop(dialogCtx);

                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GruvboxColors.bg1,
                        content: Text(
                          'Added YAML Frontmatter to ${activeTab.fileName}',
                          style: TextStyle(color: GruvboxColors.green),
                        ),
                      ),
                    );
                  },
                  child: const Text('Insert Frontmatter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFrontMatterField(String label, TextEditingController ctrl, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: GruvboxColors.gray, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: TextStyle(color: GruvboxColors.fg, fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: GruvboxColors.bgHard,
            hintText: hint,
            hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: GruvboxColors.bg3),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
      ],
    );
  }

  void _handleThemedExport(BuildContext context) {
    final activeTab = ref.read(editorProvider).activeTab;
    if (activeTab == null) return;
    final activeTheme = ref.read(themeProvider).activeTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: activeTheme.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Themed HTML Export', style: TextStyle(color: activeTheme.fg, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Export "${activeTab.fileName}" styled with "${activeTheme.name}" color palette.',
                style: TextStyle(color: activeTheme.fgMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Icon(Icons.copy, color: activeTheme.accent),
                title: Text('Copy Themed HTML to Clipboard', style: TextStyle(color: activeTheme.fg, fontSize: 14)),
                subtitle: Text('Self-contained HTML file ready to share, open, or print to PDF', style: TextStyle(color: activeTheme.fgMuted, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ThemedExportService.instance.copyHtmlToClipboard(
                    title: activeTab.fileName.replaceAll('.md', ''),
                    markdownContent: activeTab.content,
                    theme: activeTheme,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: activeTheme.bg1,
                        content: Text('Themed HTML copied to clipboard!', style: TextStyle(color: activeTheme.green)),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.iconColor ?? GruvboxColors.fg4;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: IconButton(
        icon: Icon(widget.icon, size: 18),
        tooltip: widget.tooltip,
        color: _isHovered ? GruvboxColors.aqua : defaultColor,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: widget.onPressed,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: GruvboxColors.bg3,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
    );
  }
}
