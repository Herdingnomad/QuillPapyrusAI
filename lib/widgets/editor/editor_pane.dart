import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/editor/code_editor_widget.dart';
import 'package:quill_papyrus_ai/widgets/editor/inline_diff_widget.dart';
import 'package:quill_papyrus_ai/widgets/preview/markdown_preview.dart';

class EditorPane extends ConsumerWidget {
  const EditorPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    final workspaceState = ref.watch(workspaceProvider);
    final layoutState = ref.watch(layoutProvider);
    final activeTab = editorState.activeTab;
    final tabs = editorState.tabs;

    if (tabs.isEmpty) {
      return Container(
        color: GruvboxColors.bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.edit_note, color: GruvboxColors.gray, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No Document Open',
                style: TextStyle(color: GruvboxColors.fg, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a file from the workspace on the left or create a new one.',
                style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (workspaceState.fileTree != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GruvboxColors.bg1,
                    foregroundColor: GruvboxColors.aqua,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.note_add),
                  label: const Text('Create New File'),
                  onPressed: () => _showCreateFileDialog(context, ref, workspaceState.fileTree!.uri),
                ),
            ],
          ),
        ),
      );
    }

    final isDirty = activeTab?.isDirty ?? false;

    if (layoutState.isZenMode) {
      return Container(
        color: GruvboxColors.bg,
        child: Stack(
          children: [
            // Centered Book-width / Typewriter Editor Canvas
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Column(
                    children: [
                      const InlineDiffWidget(),
                      Expanded(
                        child: (editorState.viewMode == EditorViewMode.preview)
                            ? const MarkdownPreview()
                            : const CodeEditorWidget(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Minimal Exit Pill & Word Counter
            Positioned(
              top: 12,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bgHard.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GruvboxColors.bg3),
                    ),
                    child: Text(
                      '${editorState.wordCount} words  •  ${isDirty ? "● Unsaved" : "Saved"}',
                      style: const TextStyle(color: GruvboxColors.gray, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Exit Zen Mode',
                    child: InkWell(
                      onTap: () => ref.read(layoutProvider.notifier).exitZenMode(),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: GruvboxColors.bg1,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GruvboxColors.aqua),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fullscreen_exit, size: 14, color: GruvboxColors.aqua),
                            SizedBox(width: 4),
                            Text(
                              'Exit Zen',
                              style: TextStyle(color: GruvboxColors.fg, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: GruvboxColors.bg,
      child: Column(
        children: [
          // Tab bar & Main Editor Header
          Container(
            height: 40,
            color: GruvboxColors.bgHard,
            child: Row(
              children: [
                // Scrollable tab list with proper constraints and tooltips
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final isActive = index == editorState.activeTabIndex;

                      return Tooltip(
                        message: tab.fileName,
                        waitDuration: const Duration(milliseconds: 600),
                        child: GestureDetector(
                          onTap: () => ref.read(editorProvider.notifier).switchTab(index),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 80, maxWidth: 180),
                            padding: const EdgeInsets.only(left: 10, right: 6),
                            decoration: BoxDecoration(
                              color: isActive ? GruvboxColors.bg : GruvboxColors.bgHard,
                              border: Border(
                                top: BorderSide(
                                  color: isActive ? GruvboxColors.aqua : Colors.transparent,
                                  width: 2.5,
                                ),
                                right: const BorderSide(
                                  color: GruvboxColors.bg3,
                                  width: 1,
                                ),
                                bottom: BorderSide(
                                  color: isActive ? Colors.transparent : GruvboxColors.bg3,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab.fileName.endsWith('.md') ? Icons.description : Icons.insert_drive_file,
                                  color: isActive ? GruvboxColors.aqua : GruvboxColors.gray,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    tab.fileName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: isActive ? GruvboxColors.fg : GruvboxColors.fg4,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                if (tab.isDirty) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: GruvboxColors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 4),
                                InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => ref.read(editorProvider.notifier).closeTab(index),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: Icon(
                                      Icons.close,
                                      color: isActive ? GruvboxColors.gray : GruvboxColors.fg4,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Quick New File button
                if (workspaceState.fileTree != null)
                  IconButton(
                    icon: const Icon(Icons.add, color: GruvboxColors.gray, size: 18),
                    tooltip: 'New File',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => _showCreateFileDialog(context, ref, workspaceState.fileTree!.uri),
                  ),

                // All Open Tabs Dropdown Menu (for multi-tab management)
                if (tabs.length > 1)
                  PopupMenuButton<int>(
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg1,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: GruvboxColors.bg3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tab, size: 13, color: GruvboxColors.aqua),
                          const SizedBox(width: 3),
                          Text(
                            '${tabs.length}',
                            style: const TextStyle(
                              color: GruvboxColors.fg,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 13, color: GruvboxColors.gray),
                        ],
                      ),
                    ),
                    tooltip: 'All Open Tabs (${tabs.length})',
                    padding: EdgeInsets.zero,
                    color: GruvboxColors.bg1,
                    onSelected: (selectedIndex) {
                      if (selectedIndex == -2) {
                        // Close other tabs
                        final activeIdx = editorState.activeTabIndex;
                        for (var i = tabs.length - 1; i >= 0; i--) {
                          if (i != activeIdx) {
                            ref.read(editorProvider.notifier).closeTab(i);
                          }
                        }
                      } else if (selectedIndex >= 0) {
                        ref.read(editorProvider.notifier).switchTab(selectedIndex);
                      }
                    },
                    itemBuilder: (ctx) => [
                      ...tabs.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final t = entry.value;
                        final isCurrent = idx == editorState.activeTabIndex;
                        return PopupMenuItem<int>(
                          value: idx,
                          height: 34,
                          child: Row(
                            children: [
                              Icon(
                                isCurrent ? Icons.check : (t.fileName.endsWith('.md') ? Icons.description : Icons.insert_drive_file),
                                size: 14,
                                color: isCurrent ? GruvboxColors.aqua : GruvboxColors.gray,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.fileName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? GruvboxColors.aqua : GruvboxColors.fg,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              if (t.isDirty)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: const BoxDecoration(
                                    color: GruvboxColors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      const PopupMenuDivider(),
                      const PopupMenuItem<int>(
                        value: -2,
                        height: 30,
                        child: Row(
                          children: [
                            Icon(Icons.close_fullscreen, size: 14, color: GruvboxColors.gray),
                            SizedBox(width: 8),
                            Text('Close Other Tabs', style: TextStyle(color: GruvboxColors.fg4, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(width: 4),
                Container(width: 1, height: 18, color: GruvboxColors.bg3),
                const SizedBox(width: 2),

                // View Mode Toggles (source, split, preview)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  decoration: BoxDecoration(
                    color: GruvboxColors.bg1,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ViewModeButton(
                        icon: Icons.code,
                        tooltip: 'Source View',
                        isActive: editorState.viewMode == EditorViewMode.source,
                        onTap: () => ref.read(editorProvider.notifier).setViewMode(EditorViewMode.source),
                      ),
                      _ViewModeButton(
                        icon: Icons.vertical_split,
                        tooltip: 'Split View',
                        isActive: editorState.viewMode == EditorViewMode.split,
                        onTap: () => ref.read(editorProvider.notifier).setViewMode(EditorViewMode.split),
                      ),
                      _ViewModeButton(
                        icon: Icons.visibility,
                        tooltip: 'Preview View',
                        isActive: editorState.viewMode == EditorViewMode.preview,
                        onTap: () => ref.read(editorProvider.notifier).setViewMode(EditorViewMode.preview),
                      ),
                    ],
                  ),
                ),

                // Focus Mode Toggle Button (Distraction-Free)
                IconButton(
                  icon: Icon(
                    layoutState.isFocusMode ? Icons.fullscreen_exit : Icons.fullscreen,
                    size: 18,
                    color: layoutState.isFocusMode ? GruvboxColors.yellow : GruvboxColors.gray,
                  ),
                  tooltip: layoutState.isFocusMode ? 'Exit Focus Mode' : 'Focus Mode',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => ref.read(layoutProvider.notifier).toggleFocusMode(),
                ),
                // Zen Writing Mode Toggle Button (Centered Canvas, No Chrome)
                IconButton(
                  icon: const Icon(
                    Icons.self_improvement,
                    size: 18,
                    color: GruvboxColors.aqua,
                  ),
                  tooltip: 'Zen Writing Mode (Centered Canvas)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => ref.read(layoutProvider.notifier).toggleZenMode(),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const Divider(color: GruvboxColors.bg3, height: 1),

          // Active Inline Diff view if proposal is present
          const InlineDiffWidget(),

          // Content area
          Expanded(
            child: Row(
              children: [
                if (editorState.viewMode == EditorViewMode.source ||
                    editorState.viewMode == EditorViewMode.split)
                  const Expanded(child: CodeEditorWidget()),
                if (editorState.viewMode == EditorViewMode.split)
                  Container(width: 1, color: GruvboxColors.bg3),
                if (editorState.viewMode == EditorViewMode.preview ||
                    editorState.viewMode == EditorViewMode.split)
                  const Expanded(child: MarkdownPreview()),
              ],
            ),
          ),

          // Status bar
          Container(
            height: 24,
            color: GruvboxColors.bgHard,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ln ${editorState.cursorLine}, Col ${editorState.cursorColumn}',
                  style: const TextStyle(color: GruvboxColors.gray, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${isDirty ? "● Modified" : "Saved"}  •  UTF-8  •  ${editorState.wordCount} words  •  Markdown',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isDirty ? GruvboxColors.yellow : GruvboxColors.gray,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFileDialog(BuildContext context, WidgetRef ref, String parentUri) {
    final controller = TextEditingController(text: 'Note.md');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: const Text('Create New Markdown File', style: TextStyle(color: GruvboxColors.fg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: GruvboxColors.fg),
          decoration: const InputDecoration(
            hintText: 'File name (e.g. Note.md)',
            hintStyle: TextStyle(color: GruvboxColors.gray),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GruvboxColors.aqua,
              foregroundColor: GruvboxColors.bgHard,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final newUri = await ref.read(workspaceProvider.notifier).createFile(parentUri, name);
                if (newUri != null) {
                  ref.read(editorProvider.notifier).openFile(newUri, name);
                }
              }
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Create & Open'),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? GruvboxColors.bg2 : Colors.transparent,
            borderRadius: BorderRadius.circular(3.0),
          ),
          child: Icon(
            icon,
            color: isActive ? GruvboxColors.aqua : GruvboxColors.gray,
            size: 16,
          ),
        ),
      ),
    );
  }
}
