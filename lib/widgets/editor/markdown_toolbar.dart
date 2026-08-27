import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/diff_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

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
                  icon: const Icon(Icons.expand_less, color: GruvboxColors.aqua, size: 20),
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
            icon: const Icon(Icons.expand_more, color: GruvboxColors.gray, size: 20),
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
    final canUndo = activeTab?.canUndo == true || (widget.undoController?.value.canUndo ?? false);
    final canRedo = activeTab?.canRedo == true || (widget.undoController?.value.canRedo ?? false);

    return [
      if (widget.onSave != null) ...[
        _ToolbarButton(
          icon: Icons.save,
          tooltip: 'Save File (Ctrl+S)',
          iconColor: GruvboxColors.aqua,
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
      _ToolbarButton(icon: Icons.format_bold, tooltip: 'Bold (**text**)', onPressed: () => _wrapSelection('**', '**')),
      _ToolbarButton(icon: Icons.format_italic, tooltip: 'Italic (*text*)', onPressed: () => _wrapSelection('*', '*')),
      _ToolbarButton(icon: Icons.title, tooltip: 'Heading (# )', onPressed: () => _cycleHeading()),
      _Divider(),
      _ToolbarButton(icon: Icons.link, tooltip: 'Link ([text](url))', onPressed: () => _wrapSelection('[', '](url)')),
      _ToolbarButton(icon: Icons.image, tooltip: 'Image (![alt](url))', onPressed: () => _wrapSelection('![alt](', ')')),
      _ToolbarButton(icon: Icons.code, tooltip: 'Inline Code (`code`)', onPressed: () => _wrapSelection('`', '`')),
      _ToolbarButton(icon: Icons.integration_instructions, tooltip: 'Code Block (```)', onPressed: () => _insertCodeBlock()),
      _Divider(),
      _ToolbarButton(icon: Icons.format_list_bulleted, tooltip: 'Bullet List (- )', onPressed: () => _prefixLine('- ')),
      _ToolbarButton(icon: Icons.format_list_numbered, tooltip: 'Numbered List (1. )', onPressed: () => _prefixLine('1. ')),
      _ToolbarButton(icon: Icons.checklist, tooltip: 'Task List (- [ ] )', onPressed: () => _prefixLine('- [ ] ')),
      _Divider(),
      _ToolbarButton(icon: Icons.format_quote, tooltip: 'Blockquote (> )', onPressed: () => _prefixLine('> ')),
      _ToolbarButton(icon: Icons.horizontal_rule, tooltip: 'Horizontal Rule (---)', onPressed: () => _insertText('\n---\n')),
      _ToolbarButton(icon: Icons.table_chart_outlined, tooltip: 'Table', onPressed: () => _insertTable()),
    ];
  }

  Widget _buildAiMenuButton(BuildContext context) {
    if (_isAiLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.0),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: GruvboxColors.aqua),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.auto_awesome, color: GruvboxColors.yellow, size: 18),
      tooltip: 'Gemma 4 AI Actions',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      color: GruvboxColors.bg1,
      onSelected: (action) => _handleAiAction(context, action),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'grammar',
          child: Row(
            children: [
              Icon(Icons.spellcheck, color: GruvboxColors.aqua, size: 16),
              SizedBox(width: 8),
              Text('Fix Grammar & Phrasing', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'expand',
          child: Row(
            children: [
              Icon(Icons.unfold_more, color: GruvboxColors.blue, size: 16),
              SizedBox(width: 8),
              Text('Deepen & Expand', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'summarize',
          child: Row(
            children: [
              Icon(Icons.notes, color: GruvboxColors.green, size: 16),
              SizedBox(width: 8),
              Text('Summarize to Bullets', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'action_items',
          child: Row(
            children: [
              Icon(Icons.checklist, color: GruvboxColors.orange, size: 16),
              SizedBox(width: 8),
              Text('Extract Action Items', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'explain',
          child: Row(
            children: [
              Icon(Icons.school_outlined, color: GruvboxColors.purple, size: 16),
              SizedBox(width: 8),
              Text('Explain & Simplify', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'table',
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, color: GruvboxColors.yellow, size: 16),
              SizedBox(width: 8),
              Text('Convert to Table', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'outline',
          child: Row(
            children: [
              Icon(Icons.format_list_numbered, color: GruvboxColors.darkAqua, size: 16),
              SizedBox(width: 8),
              Text('Generate Outline', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'concise',
          child: Row(
            children: [
              Icon(Icons.compress, color: GruvboxColors.darkOrange, size: 16),
              SizedBox(width: 8),
              Text('Make Concise', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAiAction(BuildContext context, String action) async {
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
      start = selection.start;
      end = selection.end;
      targetText = text.substring(start, end);
      isSelection = true;
    }

    if (targetText.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
      'grammar': 'Grammar & Style Fix',
      'expand': 'Expanded Section',
      'summarize': 'Summary Bullets',
      'action_items': 'Action Items Checklist',
      'explain': 'Concept Explanation',
      'table': 'Markdown Table',
      'outline': 'Document Outline',
      'concise': 'Concise Revision',
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
            style: const TextStyle(color: GruvboxColors.aqua),
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

      final proposal = DiffService.createProposal(
        originalFullText: text,
        proposedReplacement: cleanResult.isNotEmpty ? cleanResult : result,
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
              'Proposed $actionTitle — Tap Accept or Reject above the editor',
              style: const TextStyle(color: GruvboxColors.green),
            ),
          ),
        );
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
              style: const TextStyle(color: GruvboxColors.red),
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
