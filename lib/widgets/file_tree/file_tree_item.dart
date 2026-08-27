import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class FileTreeItem extends ConsumerStatefulWidget {
  final FileNode node;
  final int indentLevel;

  const FileTreeItem({
    super.key,
    required this.node,
    required this.indentLevel,
  });

  @override
  ConsumerState<FileTreeItem> createState() => _FileTreeItemState();
}

class _FileTreeItemState extends ConsumerState<FileTreeItem> {
  bool _isDragHovered = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final indentLevel = widget.indentLevel;

    final activeFileUri = ref.watch(editorProvider).activeFileUri;
    final isSelected = activeFileUri == node.uri;
    final isDirectory = node.isDirectory;
    final isExpanded = ref.watch(workspaceProvider).expandedDirs.contains(node.uri);
    final isMd = node.name.toLowerCase().endsWith('.md');
    final hasUnsavedChanges = ref.watch(editorProvider).tabs.any((t) => t.uri == node.uri && t.isDirty);

    final Widget baseRow = Container(
      decoration: BoxDecoration(
        color: _isDragHovered
            ? GruvboxColors.aqua.withValues(alpha: 0.25)
            : (isSelected ? GruvboxColors.bg2 : Colors.transparent),
        border: _isDragHovered
            ? Border.all(color: GruvboxColors.aqua, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(3.0),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
      child: Row(
        children: [
          SizedBox(width: indentLevel * 14.0),
          if (indentLevel > 0)
            Container(
              width: 1,
              height: 20,
              color: GruvboxColors.bg3,
              margin: const EdgeInsets.only(right: 6),
            ),
          if (isDirectory)
            Icon(
              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              color: GruvboxColors.gray,
              size: 16,
            ),
          if (!isDirectory) const SizedBox(width: 16),
          Icon(
            isDirectory
                ? (isExpanded ? Icons.folder_open : Icons.folder)
                : (isMd ? Icons.description : Icons.insert_drive_file),
            color: isDirectory
                ? (isExpanded ? GruvboxColors.orange : GruvboxColors.yellow)
                : (isMd ? GruvboxColors.blue : GruvboxColors.gray),
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              node.name,
              style: TextStyle(
                color: isSelected ? GruvboxColors.fg0 : GruvboxColors.fg,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasUnsavedChanges)
            Container(
              margin: const EdgeInsets.only(right: 6),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: GruvboxColors.orange,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );

    Widget itemContent = baseRow;

    // If directory, accept drop targets
    if (isDirectory) {
      itemContent = DragTarget<FileNode>(
        onWillAcceptWithDetails: (details) {
          final incoming = details.data;
          if (incoming.uri == node.uri) return false;
          // Cannot drop a folder into its own descendant
          if (node.uri.startsWith(incoming.uri)) return false;
          return true;
        },
        onAcceptWithDetails: (details) async {
          setState(() {
            _isDragHovered = false;
          });
          final incoming = details.data;
          final success = await ref.read(workspaceProvider.notifier).moveNode(incoming.uri, node.uri);
          if (context.mounted && success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: GruvboxColors.bg1,
                duration: const Duration(seconds: 1),
                content: Text(
                  'Moved ${incoming.name} into ${node.name}',
                  style: const TextStyle(color: GruvboxColors.green),
                ),
              ),
            );
          }
        },
        onLeave: (_) {
          setState(() {
            _isDragHovered = false;
          });
        },
        onMove: (_) {
          if (!_isDragHovered) {
            setState(() {
              _isDragHovered = true;
            });
          }
        },
        builder: (context, candidateData, rejectedData) => baseRow,
      );
    }

    // Draggable wrapper
    Widget draggableItem = LongPressDraggable<FileNode>(
      data: node,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: GruvboxColors.aqua),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                node.isDirectory ? Icons.folder : Icons.description,
                size: 16,
                color: node.isDirectory ? GruvboxColors.orange : GruvboxColors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                node.name,
                style: const TextStyle(color: GruvboxColors.fg, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: itemContent),
      child: InkWell(
        onTap: () {
          if (isDirectory) {
            ref.read(workspaceProvider.notifier).toggleDirectoryExpansion(node.uri);
          } else {
            ref.read(editorProvider.notifier).openFile(node.uri, node.name);
          }
        },
        onLongPress: () {
          _showContextMenu(context, ref);
        },
        child: itemContent,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        draggableItem,
        if (isDirectory && isExpanded)
          ...node.sortedChildren.map((child) => FileTreeItem(
                node: child,
                indentLevel: indentLevel + 1,
              )),
      ],
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        overlay.localToGlobal(Offset.zero),
        overlay.localToGlobal(overlay.size.bottomRight(Offset.zero)),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: GruvboxColors.bg1,
      items: [
        if (widget.node.isDirectory) ...[
          const PopupMenuItem(
            value: 'new_file',
            child: Row(
              children: [
                Icon(Icons.note_add, size: 16, color: GruvboxColors.aqua),
                SizedBox(width: 8),
                Text('New File', style: TextStyle(color: GruvboxColors.fg)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'new_folder',
            child: Row(
              children: [
                Icon(Icons.create_new_folder, size: 16, color: GruvboxColors.yellow),
                SizedBox(width: 8),
                Text('New Folder', style: TextStyle(color: GruvboxColors.fg)),
              ],
            ),
          ),
        ],
        const PopupMenuItem(
          value: 'move_to',
          child: Row(
            children: [
              Icon(Icons.drive_file_move_outlined, size: 16, color: GruvboxColors.orange),
              SizedBox(width: 8),
              Text('Move to Folder...', style: TextStyle(color: GruvboxColors.fg)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16, color: GruvboxColors.blue),
              SizedBox(width: 8),
              Text('Rename', style: TextStyle(color: GruvboxColors.fg)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: GruvboxColors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: GruvboxColors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      if (value == 'new_file') {
        _showCreateDialog(context, ref, isFolder: false);
      } else if (value == 'new_folder') {
        _showCreateDialog(context, ref, isFolder: true);
      } else if (value == 'move_to') {
        _showMoveToDialog(context, ref);
      } else if (value == 'rename') {
        _showRenameDialog(context, ref);
      } else if (value == 'delete') {
        _showDeleteConfirmation(context, ref);
      }
    });
  }

  void _showMoveToDialog(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.read(workspaceProvider);
    final root = workspaceState.fileTree;
    if (root == null) return;

    // Collect all directories in the workspace
    final List<FileNode> directories = [];
    void collectDirs(FileNode n) {
      if (n.isDirectory) {
        if (n.uri != widget.node.uri && !n.uri.startsWith(widget.node.uri)) {
          directories.add(n);
        }
        for (final child in n.children) {
          collectDirs(child);
        }
      }
    }

    collectDirs(root);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: Text('Move ${widget.node.name} to...', style: const TextStyle(color: GruvboxColors.fg)),
        content: SizedBox(
          width: double.maxFinite,
          child: directories.isEmpty
              ? const Text('No other directories available.', style: TextStyle(color: GruvboxColors.gray))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: directories.length,
                  itemBuilder: (ctx, index) {
                    final dir = directories[index];
                    return ListTile(
                      leading: const Icon(Icons.folder, color: GruvboxColors.yellow, size: 20),
                      title: Text(
                        dir.path.isEmpty ? '${dir.name} (Root)' : dir.path,
                        style: const TextStyle(color: GruvboxColors.fg, fontSize: 13),
                      ),
                      onTap: () async {
                        Navigator.pop(dialogCtx);
                        final success = await ref.read(workspaceProvider.notifier).moveNode(widget.node.uri, dir.uri);
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: GruvboxColors.bg1,
                              content: Text(
                                'Moved ${widget.node.name} to ${dir.name}',
                                style: const TextStyle(color: GruvboxColors.green),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, {required bool isFolder}) {
    final controller = TextEditingController(text: isFolder ? '' : 'NewDocument.md');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: Text(
          isFolder ? 'Create Folder' : 'Create File',
          style: const TextStyle(color: GruvboxColors.fg),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: GruvboxColors.fg),
          decoration: InputDecoration(
            hintText: isFolder ? 'Folder name' : 'File name (.md)',
            hintStyle: const TextStyle(color: GruvboxColors.gray),
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
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (isFolder) {
                  ref.read(workspaceProvider.notifier).createDirectory(widget.node.uri, name);
                } else {
                  ref.read(workspaceProvider.notifier).createFile(widget.node.uri, name);
                }
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: widget.node.name);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: const Text('Rename', style: TextStyle(color: GruvboxColors.fg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: GruvboxColors.fg),
          decoration: const InputDecoration(
            hintText: 'New name',
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
              backgroundColor: GruvboxColors.blue,
              foregroundColor: GruvboxColors.bgHard,
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != widget.node.name) {
                ref.read(workspaceProvider.notifier).renameNode(widget.node.uri, newName);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: const Text('Delete', style: TextStyle(color: GruvboxColors.fg)),
        content: Text(
          'Are you sure you want to delete ${widget.node.name}?',
          style: const TextStyle(color: GruvboxColors.fg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GruvboxColors.red,
              foregroundColor: GruvboxColors.bgHard,
            ),
            onPressed: () {
              ref.read(workspaceProvider.notifier).deleteNode(widget.node.uri);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
