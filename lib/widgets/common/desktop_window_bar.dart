import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/services/quick_note_service.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
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
        final showTrafficDots = width >= 900;
        final showPillLabels = width >= 800;
        final showFullSearchBox = width >= 950;
        final maxBreadcrumbWidth = (width * 0.28).clamp(80.0, 240.0);

        return FrostedChrome(
          blur: 24.0,
          backgroundColor: GruvboxColors.bgGlassElevated,
          border: Border(
            bottom: BorderSide(
              color: GruvboxColors.hairlineBorder,
              width: 0.75,
            ),
          ),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                // Left: Decorative traffic dots (on wider screens) + App Identity
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showTrafficDots) ...[
                      _TrafficDot(color: GruvboxColors.red.withValues(alpha: 0.85)),
                      const SizedBox(width: 5),
                      _TrafficDot(color: GruvboxColors.yellow.withValues(alpha: 0.85)),
                      const SizedBox(width: 5),
                      _TrafficDot(color: GruvboxColors.green.withValues(alpha: 0.85)),
                      const SizedBox(width: 10),
                    ],
                    Icon(Icons.edit_note, size: 19, color: GruvboxColors.aqua),
                    const SizedBox(width: 6),
                    Text(
                      'Quill & Papyrus',
                      style: TextStyle(
                        color: GruvboxColors.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: GruvboxColors.subtleDivider),
                const SizedBox(width: 8),

                // Left Pane Toggle Pill
                _HeaderPillButton(
                  icon: Icons.folder_outlined,
                  label: showPillLabels ? 'Explorer' : null,
                  isActive: layoutState.isLeftPaneVisible,
                  tooltip: 'Toggle File Tree (Ctrl+B)',
                  onTap: () => ref.read(layoutProvider.notifier).toggleLeftPane(),
                ),

                const SizedBox(width: 4),

                // Right Pane / Sidecar Toggle Pill
                _HeaderPillButton(
                  icon: Icons.smart_toy_outlined,
                  label: showPillLabels ? 'AI & Studio' : null,
                  isActive: layoutState.isRightPaneVisible,
                  tooltip: 'Toggle AI Assistant & Tools (Ctrl+J)',
                  onTap: () => ref.read(layoutProvider.notifier).toggleRightPane(),
                ),

                const SizedBox(width: 8),

                // Center Document Breadcrumb Pill
                Expanded(
                  child: Center(
                    child: activeTab != null
                        ? TactilePressable(
                            tooltip: 'Current Document • Click for Quick Open (Ctrl+P)',
                            onTap: () => QuickOpenDialog.show(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: GruvboxColors.bgHard.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    activeTab.fileName.endsWith('.md') ? Icons.description : Icons.insert_drive_file,
                                    size: 13,
                                    color: GruvboxColors.aqua,
                                  ),
                                  const SizedBox(width: 5),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxBreadcrumbWidth),
                                    child: Text(
                                      activeTab.fileName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: GruvboxColors.fg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (activeTab.isDirty) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: GruvboxColors.orange,
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
                                ? 'Workspace: ${workspaceState.rootUri!.split(RegExp(r'[/\\]')).last}'
                                : 'Creative Writing Studio',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: GruvboxColors.gray,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: GruvboxColors.bgHard.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GruvboxColors.subtleDivider, width: 0.75),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 14, color: GruvboxColors.gray),
                          const SizedBox(width: 5),
                          Text(
                            'Quick Open',
                            style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: GruvboxColors.bg1,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'Ctrl P',
                              style: TextStyle(
                                color: GruvboxColors.fg4,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
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

                const SizedBox(width: 2),

                // Compile Manuscript
                _HeaderIconButton(
                  icon: Icons.print_outlined,
                  tooltip: 'Compile Manuscript (EPUB / PDF)',
                  iconColor: GruvboxColors.purple,
                  onTap: () => CompilerDialog.show(context),
                ),

                const SizedBox(width: 2),

                // Theme Manager
                _HeaderIconButton(
                  icon: Icons.palette_outlined,
                  tooltip: 'Color Themes & Styling',
                  iconColor: GruvboxColors.yellow,
                  onTap: () => showThemeManagerDialog(context, ref),
                ),

                const SizedBox(width: 2),

                // Enter Zen Writing Mode
                _HeaderIconButton(
                  icon: Icons.fullscreen,
                  tooltip: 'Zen Mode (Distraction Free)',
                  iconColor: GruvboxColors.green,
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

class _TrafficDot extends StatelessWidget {
  final Color color;
  const _TrafficDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderPillButton({
    required this.icon,
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
          color: isActive ? GruvboxColors.aqua.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActive ? GruvboxColors.aqua.withValues(alpha: 0.45) : Colors.transparent,
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? GruvboxColors.aqua : GruvboxColors.gray,
            ),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(
                label!,
                style: TextStyle(
                  color: isActive ? GruvboxColors.aqua : GruvboxColors.fg4,
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return TactilePressable(
      pressedScale: 0.92,
      tooltip: tooltip,
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 17,
          color: iconColor ?? GruvboxColors.fg4,
        ),
      ),
    );
  }
}
