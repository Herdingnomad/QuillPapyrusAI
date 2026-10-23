import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/app_motion.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/tactile_pressable.dart';
import 'package:quill_papyrus_ai/widgets/ai/ai_panel.dart';
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

    return Container(
      color: GruvboxColors.bg,
      child: Column(
        children: [
          // Sidecar tab bar
          Container(
            height: 38,
            color: GruvboxColors.bg1,
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                _buildTabButton(
                  tab: SidecarTab.aiAssistant,
                  icon: Icons.psychology_outlined,
                  label: 'AI',
                ),
                _buildTabButton(
                  tab: SidecarTab.documentMap,
                  icon: Icons.list_alt,
                  label: 'Outline',
                ),
                _buildTabButton(
                  tab: SidecarTab.grammarCheck,
                  icon: Icons.spellcheck,
                  label: 'Grammar',
                ),
                _buildTabButton(
                  tab: SidecarTab.sceneMetadata,
                  icon: Icons.tune,
                  label: 'Scene',
                ),
                _buildTabButton(
                  tab: SidecarTab.corkboard,
                  icon: Icons.dashboard_outlined,
                  label: 'Board',
                ),
              ],
            ),
          ),
          Divider(color: GruvboxColors.subtleDivider, height: 1),

          // Active tab view (lazy loaded for maximum performance and file isolation)
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
            : Center(
                child: Text(
                  'Open a document to view heading outline',
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                ),
              );
      case SidecarTab.grammarCheck:
        return activeTab != null
            ? GrammarCheckWidget(
                content: activeTab.content,
                onNavigateToLine: (line, offset) {
                  ref.read(editorProvider.notifier).updateCursor(line, 1);
                },
              )
            : Center(
                child: Text(
                  'Open a document to check grammar & spelling',
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                ),
              );
      case SidecarTab.sceneMetadata:
        return const SceneMetadataInspector();
      case SidecarTab.corkboard:
        return targetFolder != null
            ? CorkboardView(folderNode: targetFolder)
            : Center(
                child: Text(
                  'Select a folder in workspace to view corkboard',
                  style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                ),
              );
    }
  }

  Widget _buildTabButton({
    required SidecarTab tab,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == tab;

    return Expanded(
      child: TactilePressable(
        tooltip: label,
        pressedScale: 0.94,
        onTap: () => setState(() => _activeTab = tab),
        child: AnimatedContainer(
          duration: AppMotion.fastTransition,
          curve: AppMotion.snappyEaseOut,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? GruvboxColors.bg2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: GruvboxColors.hairlineBorder, width: 0.75)
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? GruvboxColors.yellow : GruvboxColors.gray,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? GruvboxColors.fg0 : GruvboxColors.gray,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
