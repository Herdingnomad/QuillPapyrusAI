import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/ai/ai_panel.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/corkboard/corkboard_view.dart';
import 'package:quill_papyrus_ai/widgets/editor/document_map_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/grammar_check_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/scene_metadata_inspector.dart';

enum SidecarTab {
  aiAssistant,
  documentMap,
  grammarCheck,
  sceneMetadata,
  corkboard,
}

class SidecarPane extends ConsumerStatefulWidget {
  const SidecarPane({super.key});

  @override
  ConsumerState<SidecarPane> createState() => _SidecarPaneState();
}

class _SidecarPaneState extends ConsumerState<SidecarPane> {
  SidecarTab _activeTab = SidecarTab.aiAssistant;

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final workspaceState = ref.watch(workspaceProvider);
    final activeTab = editorState.activeTab;

    FileNode? targetFolder;
    if (workspaceState.fileTree != null) {
      if (workspaceState.selectedFolderUri != null) {
        targetFolder = workspaceState.fileTree!.findByUri(workspaceState.selectedFolderUri!);
      }
      targetFolder ??= workspaceState.fileTree;
    }

    return ColoredBox(
      color: GruvboxColors.bgHard,
      child: Column(
        children: [
          // Recessed Segmented Studio Switcher
          Container(
            height: 40,
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
            decoration: BoxDecoration(
              color: GruvboxColors.bgHard,
              border: Border(
                bottom: BorderSide(color: GruvboxColors.subtleDivider, width: 0.75),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: GruvboxColors.bg.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GruvboxColors.subtleDivider, width: 0.5),
              ),
              child: Row(
                children: [
                  _buildTabButton(
                    tab: SidecarTab.aiAssistant,
                    customLeading: (selected) => InkQuillSparkMark(
                      size: 13.5,
                      color: selected ? GruvboxColors.accent : GruvboxColors.fgMuted,
                    ),
                    label: 'AI',
                  ),
                  _buildTabButton(
                    tab: SidecarTab.documentMap,
                    icon: Icons.segment_rounded,
                    label: 'Outline',
                  ),
                  _buildTabButton(
                    tab: SidecarTab.grammarCheck,
                    icon: Icons.spellcheck_rounded,
                    label: 'Grammar',
                  ),
                  _buildTabButton(
                    tab: SidecarTab.sceneMetadata,
                    icon: Icons.tune_rounded,
                    label: 'Scene',
                  ),
                  _buildTabButton(
                    tab: SidecarTab.corkboard,
                    icon: Icons.grid_view_rounded,
                    label: 'Board',
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _buildActiveTabContent(activeTab, targetFolder),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(dynamic activeTab, FileNode? targetFolder) {
    switch (_activeTab) {
      case SidecarTab.aiAssistant:
        return const AiPanel();
      case SidecarTab.documentMap:
        return activeTab != null
            ? DocumentMapWidget(
                content: activeTab.content,
                onHeadingSelected: (line, offset) {
                  ref.read(editorProvider.notifier).updateCursor(line, 1);
                },
              )
            : _buildQuietEmptyHint('Open a manuscript to inspect its heading outline');
      case SidecarTab.grammarCheck:
        return activeTab != null
            ? GrammarCheckWidget(
                content: activeTab.content,
                onNavigateToLine: (line, offset) {
                  ref.read(editorProvider.notifier).updateCursor(line, 1);
                },
              )
            : _buildQuietEmptyHint('Open a manuscript to review prose & spelling');
      case SidecarTab.sceneMetadata:
        return const SceneMetadataInspector();
      case SidecarTab.corkboard:
        return targetFolder != null
            ? CorkboardView(folderNode: targetFolder)
            : _buildQuietEmptyHint('Select a folder in the binder to view scene index cards');
    }
  }

  Widget _buildQuietEmptyHint(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required SidecarTab tab,
    IconData? icon,
    Widget Function(bool isSelected)? customLeading,
    required String label,
  }) {
    final isSelected = _activeTab == tab;

    return Expanded(
      child: TactilePressable(
        tooltip: label,
        pressedScale: 0.95,
        onTap: () => setState(() => _activeTab = tab),
        child: AnimatedContainer(
          duration: AppMotion.fastTransition,
          curve: AppMotion.snappyEaseOut,
          decoration: BoxDecoration(
            color: isSelected ? GruvboxColors.bg1 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: GruvboxColors.hairlineBorder, width: 0.75)
                : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customLeading != null)
                customLeading(isSelected)
              else if (icon != null)
                Icon(
                  icon,
                  size: 13.5,
                  color: isSelected ? GruvboxColors.accent : GruvboxColors.fgMuted,
                ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.uiLabel(
                    isSelected ? GruvboxColors.fg : GruvboxColors.fgMuted,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
