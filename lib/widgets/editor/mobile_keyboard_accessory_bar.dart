import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/ai_provider.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/services/diff_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/editor/markdown_formatting_helper.dart';
import 'package:quill_papyrus_ai/widgets/editor/voice_recorder_sheet.dart';

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
    final activeFont = ref.watch(layoutProvider.select((s) => s.editorFont));

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
              child: Icon(Icons.undo_rounded, size: 17, color: GruvboxColors.fg2),
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
              child: Icon(Icons.redo_rounded, size: 17, color: GruvboxColors.fg2),
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
                style: AppTypography.uiLabel(
                  GruvboxColors.fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
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
                  fontFamily: AppTypography.serifFamily,
                  color: GruvboxColors.fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
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
                  fontFamily: AppTypography.serifFamily,
                  color: GruvboxColors.fg,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              onTap: () => MarkdownFormattingHelper.wrapSelection(controller, '*', '*'),
            ),

            // Checklist (icon strictly preserved for widget tests)
            _AccessoryButton(
              tooltip: 'Checklist (- [ ])',
              child: Icon(Icons.check_box_outlined, size: 16.5, color: GruvboxColors.fg2),
              onTap: () => MarkdownFormattingHelper.toggleCheckbox(controller),
            ),

            // Bullet List (icon strictly preserved for widget tests)
            _AccessoryButton(
              tooltip: 'Bullet List (-)',
              child: Icon(Icons.format_list_bulleted, size: 17, color: GruvboxColors.fg2),
              onTap: () => MarkdownFormattingHelper.prefixLine(controller, '- '),
            ),

            // Blockquote
            _AccessoryButton(
              tooltip: 'Quote (> )',
              child: Icon(Icons.format_quote_rounded, size: 17, color: GruvboxColors.fg2),
              onTap: () => MarkdownFormattingHelper.prefixLine(controller, '> '),
            ),

            // Inline Code
            _AccessoryButton(
              tooltip: 'Code (`code`)',
              child: Icon(Icons.code_rounded, size: 16.5, color: GruvboxColors.fg2),
              onTap: () => MarkdownFormattingHelper.wrapSelection(controller, '`', '`'),
            ),

            _AccessoryDivider(),

            // Editor Font Switcher (5 offline fonts)
            _AccessoryButton(
              tooltip: 'Editor Font (${activeFont.label})',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aa',
                    style: activeFont.editorStyle(
                      color: GruvboxColors.fg,
                      fontSizeOverride: 12.5,
                      heightOverride: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              onTap: () => _showTypefaceSheet(context, ref, activeFont),
            ),

            // Quick AI Polish / Write action
            _AccessoryButton(
              tooltip: 'AI Actions (Polish, Continue)',
              isAccent: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkQuillSparkMark(size: 14, color: GruvboxColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    'AI',
                    style: AppTypography.uiLabel(
                      GruvboxColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              onTap: () => _showQuickAiMenu(context, ref),
            ),

            _AccessoryDivider(),

            // Voice Memo Recording
            _AccessoryButton(
              tooltip: 'Record Voice Memo',
              child: Icon(Icons.mic_none_rounded, size: 17.5, color: GruvboxColors.fg2),
              onTap: () {
                HapticFeedback.selectionClick();
                VoiceRecorderSheet.show(context);
              },
            ),

            // Dismiss Keyboard button
            if (onDismissKeyboard != null) ...[
              _AccessoryDivider(),
              _AccessoryButton(
                tooltip: 'Dismiss Keyboard',
                onTap: onDismissKeyboard!,
                child: Icon(Icons.keyboard_hide_outlined, size: 17.5, color: GruvboxColors.fgMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTypefaceSheet(
    BuildContext context,
    WidgetRef ref,
    EditorFontFamily currentFont,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return FrostedChrome(
          blur: 24.0,
          backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.96),
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
                      FountainNibMark(size: 16, color: GruvboxColors.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Editor Font',
                        style: AppTypography.sectionTitle(GruvboxColors.fg, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Divider(color: GruvboxColors.subtleDivider, height: 14),
                ...EditorFontFamily.values.map((font) {
                  final selected = font == currentFont;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 17,
                      color: selected ? GruvboxColors.accent : GruvboxColors.fgMuted,
                    ),
                    title: Text(
                      font.label,
                      style: font.editorStyle(
                        color: selected ? GruvboxColors.accent : GruvboxColors.fg,
                        fontSizeOverride: 14,
                        heightOverride: 1.25,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      font.subtitle,
                      style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 11),
                    ),
                    onTap: () {
                      ref.read(layoutProvider.notifier).setEditorFont(font);
                      Navigator.pop(sheetCtx);
                    },
                  );
                }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
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
          backgroundColor: GruvboxColors.bgHard.withValues(alpha: 0.95),
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
                      InkQuillSparkMark(color: GruvboxColors.accent, size: 17),
                      const SizedBox(width: 8),
                      Text(
                        'AI Actions',
                        style: AppTypography.sectionTitle(GruvboxColors.fg, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Divider(color: GruvboxColors.subtleDivider, height: 16),
                _AiSheetAction(
                  icon: Icons.brush_outlined,
                  title: 'Polish & Refine Text',
                  subtitle: 'Improve clarity, tone, and flow',
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
                  title: 'Continue Text',
                  subtitle: 'Generate the next logical paragraph',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _executeAiAction(context, ref, 'continue_writing');
                  },
                ),
                _AiSheetAction(
                  icon: Icons.compress_rounded,
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
        content: Text('AI is crafting changes...', style: TextStyle(color: GruvboxColors.accent)),
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
  final bool isAccent;

  const _AccessoryButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      pressedScale: 0.94,
      tooltip: tooltip,
      onTap: onTap,
      child: Container(
        height: 33,
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 9.0),
        decoration: BoxDecoration(
          color: isAccent
              ? GruvboxColors.accent.withValues(alpha: 0.11)
              : GruvboxColors.bg1.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isAccent
                ? GruvboxColors.accent.withValues(alpha: 0.35)
                : GruvboxColors.subtleDivider,
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
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 9.0),
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
              child: Icon(icon, size: 19, color: GruvboxColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.uiLabel(
                      GruvboxColors.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.uiLabel(
                      GruvboxColors.fgMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: GruvboxColors.fgMuted),
          ],
        ),
      ),
    );
  }
}
