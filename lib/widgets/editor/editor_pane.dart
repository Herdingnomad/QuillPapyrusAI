import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
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
    final activeTab = editorState.activeTab;
    final tabs = editorState.tabs;
    final workspaceState = ref.watch(workspaceProvider);

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
                // Scrollable tab list
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: tabs.length,
                    itemBuilder: (context, index) {
                      final tab = tabs[index];
                      final isActive = index == editorState.activeTabIndex;

                      return GestureDetector(
                        onTap: () => ref.read(editorProvider.notifier).switchTab(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isActive ? GruvboxColors.bg1 : GruvboxColors.bgHard,
                            border: Border(
                              bottom: BorderSide(
                                color: isActive ? GruvboxColors.aqua : Colors.transparent,
                                width: 2,
                              ),
                              right: const BorderSide(
                                color: GruvboxColors.bg3,
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
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tab.fileName,
                                style: TextStyle(
                                  color: isActive ? GruvboxColors.fg : GruvboxColors.fg4,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              if (tab.isDirty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: GruvboxColors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => ref.read(editorProvider.notifier).closeTab(index),
                                child: Icon(
                                  Icons.close,
                                  color: isActive ? GruvboxColors.gray : GruvboxColors.fg4,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Quick New File button
                if (workspaceState.fileTree != null)
                  IconButton(
                    icon: const Icon(Icons.add, color: GruvboxColors.gray, size: 20),
                    tooltip: 'New File',
                    onPressed: () => _showCreateFileDialog(context, ref, workspaceState.fileTree!.uri),
                  ),

                // Prominent Save Button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDirty ? GruvboxColors.orange : GruvboxColors.bg1,
                      foregroundColor: isDirty ? GruvboxColors.bgHard : GruvboxColors.gray,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(64, 30),
                      elevation: 0,
                    ),
                    icon: Icon(
                      Icons.save,
                      size: 14,
                      color: isDirty ? GruvboxColors.bgHard : (activeTab != null ? GruvboxColors.fg : GruvboxColors.gray),
                    ),
                    label: Text(
                      isDirty ? 'Save *' : 'Save',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isDirty ? FontWeight.bold : FontWeight.normal,
                        color: isDirty ? GruvboxColors.bgHard : (activeTab != null ? GruvboxColors.fg : GruvboxColors.gray),
                      ),
                    ),
                    onPressed: isDirty
                        ? () {
                            ref.read(editorProvider.notifier).saveActiveFile();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: GruvboxColors.bg1,
                                duration: const Duration(seconds: 1),
                                content: Text(
                                  'Saved ${activeTab?.fileName ?? "file"}',
                                  style: const TextStyle(color: GruvboxColors.green),
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ),

                // View Mode Toggles
                Container(
                  margin: const EdgeInsets.only(left: 4.0, right: 6.0),
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
