import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/editor/markdown_formatting_helper.dart';

class MobileKeyboardAccessoryBar extends ConsumerWidget {
  final TextEditingController controller;
  final UndoHistoryController? undoController;
  final VoidCallback? onDismissKeyboard;

  const MobileKeyboardAccessoryBar({
    super.key,
    required this.controller,
    this.undoController,
    this.onDismissKeyboard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FrostedChrome(
      blur: 16.0,
      backgroundColor: GruvboxColors.bgGlass,
      border: Border(
        top: BorderSide(
          color: GruvboxColors.hairlineBorder,
          width: 0.75,
        ),
      ),
      child: SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          children: [
            // Undo
            _AccessoryButton(
              tooltip: 'Undo (Ctrl+Z)',
              child: Icon(Icons.undo, size: 18, color: GruvboxColors.fg),
              onTap: () {
                if (undoController?.value.canUndo ?? false) {
                  undoController!.undo();
                } else {
                  ref.read(editorProvider.notifier).undo();
                }
              },
            ),

            // Redo
            _AccessoryButton(
              tooltip: 'Redo (Ctrl+Y)',
              child: Icon(Icons.redo, size: 18, color: GruvboxColors.fg),
              onTap: () {
                if (undoController?.value.canRedo ?? false) {
                  undoController!.redo();
                } else {
                  ref.read(editorProvider.notifier).redo();
                }
              },
            ),

            _AccessoryDivider(),

            // Heading cycler (H1–H3)
            _AccessoryButton(
              tooltip: 'Heading Cycle (#)',
              child: Text(
                'H#',
                style: TextStyle(
                  color: GruvboxColors.yellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onTap: () => MarkdownFormattingHelper.cycleHeading(controller),
            ),

            // Bold
            _AccessoryButton(
              tooltip: 'Bold (**text**)',
              child: Text(
                'B',
                style: TextStyle(
                  color: GruvboxColors.fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              onTap: () => MarkdownFormattingHelper.wrapSelection(controller, '**', '**'),
            ),

            // Italic
            _AccessoryButton(
              tooltip: 'Italic (*text*)',
              child: Text(
                'I',
                style: TextStyle(
                  color: GruvboxColors.fg,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onTap: () => MarkdownFormattingHelper.wrapSelection(controller, '*', '*'),
            ),

            // Checklist
            _AccessoryButton(
              tooltip: 'Checklist (- [ ])',
              child: Icon(Icons.check_box_outlined, size: 17, color: GruvboxColors.green),
              onTap: () => MarkdownFormattingHelper.toggleCheckbox(controller),
            ),

            // Bullet List
            _AccessoryButton(
              tooltip: 'Bullet List (-)',
              child: Icon(Icons.format_list_bulleted, size: 17, color: GruvboxColors.aqua),
              onTap: () => MarkdownFormattingHelper.prefixLine(controller, '- '),
            ),

            // Blockquote
            _AccessoryButton(
              tooltip: 'Quote (> )',
              child: Icon(Icons.format_quote, size: 17, color: GruvboxColors.blue),
              onTap: () => MarkdownFormattingHelper.prefixLine(controller, '> '),
            ),

            // Inline Code
            _AccessoryButton(
              tooltip: 'Code (`code`)',
              child: Icon(Icons.code, size: 17, color: GruvboxColors.purple),
              onTap: () => MarkdownFormattingHelper.wrapSelection(controller, '`', '`'),
            ),

            _AccessoryDivider(),

            // Quick AI Polish / Write action
            _AccessoryButton(
              tooltip: 'AI Actions (Polish, Continue)',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 16, color: GruvboxColors.aqua),
                  const SizedBox(width: 4),
                  Text(
                    'AI',
                    style: TextStyle(
                      color: GruvboxColors.aqua,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              onTap: () => _showQuickAiMenu(context, ref),
            ),

            // Dismiss Keyboard button
            if (onDismissKeyboard != null) ...[
              _AccessoryDivider(),
              _AccessoryButton(
                tooltip: 'Dismiss Keyboard',
                onTap: onDismissKeyboard!,
                child: Icon(Icons.keyboard_hide, size: 18, color: GruvboxColors.gray),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showQuickAiMenu(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FrostedChrome(
          blur: 24.0,
          backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.94),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: GruvboxColors.hairlineBorder, width: 0.75),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: GruvboxColors.aqua, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'AI Writing Actions',
                        style: TextStyle(
                          color: GruvboxColors.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: GruvboxColors.subtleDivider, height: 16),
                _AiSheetAction(
                  icon: Icons.brush_outlined,
                  title: 'Polish & Refine Prose',
                  subtitle: 'Fix rhythm, clarity and pacing',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _executeAiAction(context, ref, 'polish');
                  },
                ),
                _AiSheetAction(
                  icon: Icons.edit_note_outlined,
                  title: 'Fix Grammar & Typos',
                  subtitle: 'Correct spelling and punctuation',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _executeAiAction(context, ref, 'fix_grammar');
                  },
                ),
                _AiSheetAction(
                  icon: Icons.play_arrow_outlined,
                  title: 'Continue Writing',
                  subtitle: 'Generate the next logical paragraph',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _executeAiAction(context, ref, 'continue_writing');
                  },
                ),
                _AiSheetAction(
                  icon: Icons.compress,
                  title: 'Summarize Document',
                  subtitle: 'Condense into executive bullet points',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _executeAiAction(context, ref, 'summarize');
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeAiAction(BuildContext context, WidgetRef ref, String action) async {
    final aiService = ref.read(aiServiceProvider);
    final aiConfig = ref.read(aiProvider).config;
    final activeTab = ref.read(editorProvider).activeTab;

    if (!aiService.isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          content: Text(
            'Load a local Gemma 4 model first in AI Assistant tab',
            style: TextStyle(color: GruvboxColors.orange),
          ),
        ),
      );
      return;
    }

    final selection = controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final targetText = hasSelection
        ? controller.text.substring(selection.start, selection.end)
        : controller.text;

    if (targetText.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GruvboxColors.bg1,
        content: Text('AI is crafting changes...', style: TextStyle(color: GruvboxColors.aqua)),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final result = await aiService.generateQuickEdit(
        action: action,
        selectedText: hasSelection ? targetText : '',
        surroundingContext: controller.text,
        config: aiConfig,
        currentDocUri: activeTab?.uri,
      );

      final clean = DiffService.extractCleanAiContent(result);
      if (hasSelection) {
        final newText = controller.text.replaceRange(selection.start, selection.end, clean);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + clean.length),
        );
        ref.read(editorProvider.notifier).updateContent(newText);
      } else {
        MarkdownFormattingHelper.insertSnippet(controller, '\n\n$clean');
        ref.read(editorProvider.notifier).updateContent(controller.text);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GruvboxColors.bg1,
            content: Text('AI action failed: $e', style: TextStyle(color: GruvboxColors.red)),
          ),
        );
      }
    }
  }
}

class _AccessoryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  const _AccessoryButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      pressedScale: 0.94,
      tooltip: tooltip,
      onTap: onTap,
      child: Container(
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 9.0),
        decoration: BoxDecoration(
          color: GruvboxColors.bg1.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: GruvboxColors.subtleDivider,
            width: 0.75,
          ),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _AccessoryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      color: GruvboxColors.subtleDivider,
    );
  }
}

class _AiSheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AiSheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      pressedScale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GruvboxColors.bg1,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GruvboxColors.subtleDivider),
              ),
              child: Icon(icon, size: 20, color: GruvboxColors.aqua),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: GruvboxColors.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: GruvboxColors.gray,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: GruvboxColors.gray),
          ],
        ),
      ),
    );
  }
}
