import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
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
    final isFolderSelected = isDirectory && ref.watch(workspaceProvider).selectedFolderUri == node.uri;
    final isExpanded = ref.watch(workspaceProvider).expandedDirs.contains(node.uri);
    final isMd = node.name.toLowerCase().endsWith('.md');
    final hasUnsavedChanges = ref.watch(editorProvider).tabs.any((t) => t.uri == node.uri && t.isDirty);

    final Widget baseRow = Container(
      decoration: BoxDecoration(
        color: _isDragHovered
            ? GruvboxColors.aqua.withValues(alpha: 0.25)
            : (isFolderSelected
                ? GruvboxColors.bg2
                : (isSelected ? GruvboxColors.bg2 : Colors.transparent)),
        border: _isDragHovered
            ? Border.all(color: GruvboxColors.aqua, width: 1.5)
            : (isFolderSelected
                ? Border.all(color: GruvboxColors.yellow.withValues(alpha: 0.5), width: 1.0)
                : null),
        borderRadius: BorderRadius.circular(3.0),
      ),
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
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
              color: isFolderSelected ? GruvboxColors.yellow : GruvboxColors.gray,
              size: 16,
            ),
          if (!isDirectory) const SizedBox(width: 16),
          Icon(
            isDirectory
                ? (isExpanded ? Icons.folder_open : Icons.folder)
                : (isMd ? Icons.description : Icons.insert_drive_file),
            color: isDirectory
                ? (isFolderSelected ? GruvboxColors.yellow : (isExpanded ? GruvboxColors.orange : GruvboxColors.yellow))
                : (isMd ? GruvboxColors.blue : GruvboxColors.gray),
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              node.name,
              style: TextStyle(
                color: isFolderSelected
                    ? GruvboxColors.yellow
                    : (isSelected ? GruvboxColors.fg0 : GruvboxColors.fg),
                fontWeight: (isFolderSelected || isSelected) ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isFolderSelected)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: GruvboxColors.yellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: GruvboxColors.yellow.withValues(alpha: 0.4)),
              ),
              child: Text(
                'SELECTED',
                style: TextStyle(
                  color: GruvboxColors.yellow,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          if (hasUnsavedChanges)
            Container(
              margin: const EdgeInsets.only(right: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: GruvboxColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 14, color: GruvboxColors.gray),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            tooltip: 'Actions',
            onPressed: () => _showContextMenu(context, ref),
          ),
        ],
      ),
    );

    Widget itemContent = baseRow;

    // If directory, accept drop targets for dragging files into this folder
    if (isDirectory) {
      itemContent = DragTarget<FileNode>(
        onWillAcceptWithDetails: (details) {
          final incoming = details.data;
          if (incoming.uri == node.uri) return false;
          // Cannot drop a folder into its own descendant
          if (node.uri.startsWith(incoming.uri)) return false;
          // Cannot drop if already directly inside this folder
          final parent = p.dirname(incoming.uri);
          if (p.equals(parent, node.uri)) return false;
          return true;
        },
        onAcceptWithDetails: (details) async {
          setState(() {
            _isDragHovered = false;
          });
          final incoming = details.data;
          final success = await ref.read(workspaceProvider.notifier).moveNode(incoming.uri, node.uri);
          if (context.mounted && success) {
            // Auto expand the folder so user sees the dropped item
            ref.read(workspaceProvider.notifier).expandDirectory(node.uri);

            // Update open tab URI if the moved file was open
            final newPath = p.join(node.uri, incoming.name);
            ref.read(editorProvider.notifier).updateFileUri(incoming.uri, newPath);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: GruvboxColors.bg1,
                duration: const Duration(seconds: 2),
                content: Text(
                  'Moved "${incoming.name}" into "${node.name}"',
                  style: TextStyle(color: GruvboxColors.green),
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

    final bool isDesktop = !Platform.isAndroid && !Platform.isIOS;

    Widget buildFeedback() {
      return Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: GruvboxColors.bg1,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: GruvboxColors.aqua, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
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
              const SizedBox(width: 8),
              Text(
                node.name,
                style: TextStyle(
                  color: GruvboxColors.fg,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final inkWellChild = InkWell(
      onTap: () {
        if (isDirectory) {
          ref.read(workspaceProvider.notifier).selectFolder(node.uri);
          ref.read(workspaceProvider.notifier).toggleDirectoryExpansion(node.uri);
        } else {
          ref.read(workspaceProvider.notifier).selectFile(node.uri);
          ref.read(editorProvider.notifier).openFile(node.uri, node.name);
        }
      },
      onSecondaryTap: () {
        _showContextMenu(context, ref);
      },
      child: itemContent,
    );

    Widget draggableItem;
    if (isDesktop) {
      draggableItem = Draggable<FileNode>(
        data: node,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: buildFeedback(),
        childWhenDragging: Opacity(opacity: 0.35, child: itemContent),
        child: inkWellChild,
      );
    } else {
      draggableItem = LongPressDraggable<FileNode>(
        data: node,
        delay: const Duration(milliseconds: 200),
        hapticFeedbackOnStart: true,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: buildFeedback(),
        childWhenDragging: Opacity(opacity: 0.35, child: itemContent),
        child: inkWellChild,
      );
    }

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
          PopupMenuItem(
            value: 'new_file',
            child: Row(
              children: [
                Icon(Icons.note_add, size: 16, color: GruvboxColors.aqua),
                SizedBox(width: 8),
                Text('New File', style: TextStyle(color: GruvboxColors.fg)),
              ],
            ),
          ),
          PopupMenuItem(
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
        PopupMenuItem(
          value: 'move_to',
          child: Row(
            children: [
              Icon(Icons.drive_file_move_outlined, size: 16, color: GruvboxColors.orange),
              SizedBox(width: 8),
              Text('Move to Folder...', style: TextStyle(color: GruvboxColors.fg)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16, color: GruvboxColors.blue),
              SizedBox(width: 8),
              Text('Rename', style: TextStyle(color: GruvboxColors.fg)),
            ],
          ),
        ),
        PopupMenuItem(
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
        title: Text('Move ${widget.node.name} to...', style: TextStyle(color: GruvboxColors.fg)),
        content: SizedBox(
          width: double.maxFinite,
          child: directories.isEmpty
              ? Text('No other directories available.', style: TextStyle(color: GruvboxColors.gray))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: directories.length,
                  itemBuilder: (ctx, index) {
                    final dir = directories[index];
                    return ListTile(
                      leading: Icon(Icons.folder, color: GruvboxColors.yellow, size: 20),
                      title: Text(
                        dir.path.isEmpty ? '${dir.name} (Root)' : dir.path,
                        style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
                      ),
                      onTap: () async {
                        Navigator.pop(dialogCtx);
                        final success = await ref.read(workspaceProvider.notifier).moveNode(widget.node.uri, dir.uri);
                        if (context.mounted && success) {
                          ref.read(workspaceProvider.notifier).expandDirectory(dir.uri);
                          final newPath = p.join(dir.uri, widget.node.name);
                          ref.read(editorProvider.notifier).updateFileUri(widget.node.uri, newPath);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: GruvboxColors.bg1,
                              content: Text(
                                'Moved ${widget.node.name} to ${dir.name}',
                                style: TextStyle(color: GruvboxColors.green),
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
            child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFolder ? 'Create Folder' : 'Create New File',
              style: TextStyle(color: GruvboxColors.fg),
            ),
            const SizedBox(height: 2),
            Text(
              'in ${widget.node.name}',
              style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: GruvboxColors.fg),
          decoration: InputDecoration(
            hintText: isFolder ? 'Folder name' : 'File name (.md)',
            hintStyle: TextStyle(color: GruvboxColors.gray),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GruvboxColors.aqua,
              foregroundColor: GruvboxColors.bgHard,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (isFolder) {
                  await ref.read(workspaceProvider.notifier).createDirectory(widget.node.uri, name);
                } else {
                  final newUri = await ref.read(workspaceProvider.notifier).createFile(widget.node.uri, name);
                  if (newUri != null) {
                    ref.read(editorProvider.notifier).openFile(newUri, name);
                  }
                }
                ref.read(workspaceProvider.notifier).expandDirectory(widget.node.uri);
                ref.read(workspaceProvider.notifier).selectFolder(widget.node.uri);
              }
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
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
        title: Text('Rename', style: TextStyle(color: GruvboxColors.fg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: GruvboxColors.fg),
          decoration: InputDecoration(
            hintText: 'New name',
            hintStyle: TextStyle(color: GruvboxColors.gray),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
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
        title: Text('Delete', style: TextStyle(color: GruvboxColors.fg)),
        content: Text(
          'Are you sure you want to delete ${widget.node.name}?',
          style: TextStyle(color: GruvboxColors.fg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
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
