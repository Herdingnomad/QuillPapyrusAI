import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/compiler_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/quick_open_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/theme_manager_dialog.dart';

class DesktopWindowBar extends ConsumerWidget {
  const DesktopWindowBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutState = ref.watch(layoutProvider);
    final editorState = ref.watch(editorProvider);
    final workspaceState = ref.watch(workspaceProvider);
    final activeTab = editorState.activeTab;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showPillLabels = width >= 820;
        final showFullSearchBox = width >= 980;
        final maxBreadcrumbWidth = (width * 0.25).clamp(80.0, 240.0);

        return FrostedChrome(
          blur: 20.0,
          backgroundColor: GruvboxColors.bgHard,
          border: Border(
            bottom: BorderSide(
              color: GruvboxColors.subtleDivider,
              width: 0.75,
            ),
          ),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                // Left: Handmade Brand Identity (Nib + Literary Wordmark)
                FountainNibMark(
                  size: 16,
                  color: GruvboxColors.accent,
                ),
                const SizedBox(width: 7),
                Text(
                  'Quill & Papyrus',
                  style: AppTypography.brandWordmark(GruvboxColors.fg, fontSize: 14.5),
                ),

                const SizedBox(width: 12),
                Container(width: 0.75, height: 14, color: GruvboxColors.subtleDivider),
                const SizedBox(width: 8),

                // Left Pane Toggle Pill
                _HeaderPillButton(
                  leading: Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: layoutState.isLeftPaneVisible ? GruvboxColors.accent : GruvboxColors.fgMuted,
                  ),
                  label: showPillLabels ? 'Files' : null,
                  isActive: layoutState.isLeftPaneVisible,
                  tooltip: 'Toggle File Tree (Ctrl+B)',
                  onTap: () => ref.read(layoutProvider.notifier).toggleLeftPane(),
                ),

                const SizedBox(width: 4),

                // Right Pane / Sidecar Toggle Pill
                _HeaderPillButton(
                  leading: InkQuillSparkMark(
                    size: 14,
                    color: layoutState.isRightPaneVisible ? GruvboxColors.accent : GruvboxColors.fgMuted,
                  ),
                  label: showPillLabels ? 'Tools' : null,
                  isActive: layoutState.isRightPaneVisible,
                  tooltip: 'Toggle AI Assistant & Tools (Ctrl+J)',
                  onTap: () => ref.read(layoutProvider.notifier).toggleRightPane(),
                ),

                const SizedBox(width: 8),

                // Center Document Folio Slip
                Expanded(
                  child: Center(
                    child: activeTab != null
                        ? TactilePressable(
                            tooltip: 'Current Document • Click for Quick Open (Ctrl+P)',
                            onTap: () => QuickOpenDialog.show(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                              decoration: BoxDecoration(
                                color: GruvboxColors.bg1.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    activeTab.isPdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined,
                                    size: 13,
                                    color: GruvboxColors.fgMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxBreadcrumbWidth),
                                    child: Text(
                                      activeTab.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.uiLabel(
                                        GruvboxColors.fg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (activeTab.isDirty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: GruvboxColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : Text(
                            workspaceState.rootUri != null
                                ? workspaceState.rootUri!.split(RegExp(r'[/\\]')).last
                                : 'Markdown Workspace',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.uiLabel(
                              GruvboxColors.fgMuted,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 8),

                // Quick Open / Search Trigger
                if (showFullSearchBox)
                  TactilePressable(
                    tooltip: 'Quick Open Files (Ctrl+P)',
                    onTap: () => QuickOpenDialog.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg1.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 13.5, color: GruvboxColors.fgMuted),
                          const SizedBox(width: 5),
                          Text(
                            'Quick Open',
                            style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 11.5),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: GruvboxColors.bg2.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Ctrl P',
                              style: AppTypography.tabularMetric(
                                GruvboxColors.fgMuted,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _HeaderIconButton(
                    icon: Icons.search,
                    tooltip: 'Quick Open (Ctrl+P)',
                    onTap: () => QuickOpenDialog.show(context),
                  ),

                const SizedBox(width: 4),

                // Quick Note (+)
                _HeaderIconButton(
                  icon: Icons.add,
                  tooltip: 'Quick Note (Ctrl+N)',
                  onTap: () => ref.read(quickNoteServiceProvider).createQuickNote(),
                ),

                // Export Document
                _HeaderIconButton(
                  icon: Icons.menu_book_outlined,
                  tooltip: 'Export Document (EPUB / PDF)',
                  onTap: () => CompilerDialog.show(context),
                ),

                // Theme Manager
                _HeaderIconButton(
                  icon: Icons.palette_outlined,
                  tooltip: 'Color Themes & Styling',
                  onTap: () => showThemeManagerDialog(context, ref),
                ),

                // Enter Focus Mode
                _HeaderIconButton(
                  icon: Icons.crop_free_rounded,
                  tooltip: 'Focus Mode (Distraction Free)',
                  onTap: () => ref.read(layoutProvider.notifier).toggleZenMode(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  final Widget leading;
  final String? label;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderPillButton({
    required this.leading,
    this.label,
    required this.isActive,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      pressedScale: 0.95,
      tooltip: tooltip,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fastTransition,
        curve: AppMotion.snappyEaseOut,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? GruvboxColors.bg1 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActive ? GruvboxColors.subtleDivider : Colors.transparent,
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: AppTypography.uiLabel(
                  isActive ? GruvboxColors.fg : GruvboxColors.fgMuted,
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TactilePressable(
        pressedScale: 0.92,
        tooltip: widget.tooltip,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.pressFeedback,
          curve: AppMotion.snappyEaseOut,
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: _hovered ? GruvboxColors.bg1 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 16.5,
            color: _hovered ? GruvboxColors.fg : GruvboxColors.fgMuted,
          ),
        ),
      ),
    );
  }
}
