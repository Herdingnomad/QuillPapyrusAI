import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/workspace_state.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/file_tree/file_tree_item.dart';

class FileTreePanel extends ConsumerStatefulWidget {
  const FileTreePanel({super.key});

  @override
  ConsumerState<FileTreePanel> createState() => _FileTreePanelState();
}

class _FileTreePanelState extends ConsumerState<FileTreePanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRootDragHovered = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = ref.watch(workspaceProvider);

    return Material(
      color: GruvboxColors.bgHard,
      child: Column(
        children: [
          // Top section: Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
              style: const TextStyle(color: GruvboxColors.fg, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: GruvboxColors.bg1,
                hintText: 'Search files...',
                hintStyle: const TextStyle(color: GruvboxColors.gray, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: GruvboxColors.gray, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: GruvboxColors.gray, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(context, workspaceState),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WorkspaceState workspaceState) {
    if (workspaceState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: GruvboxColors.aqua),
      );
    }

    if (workspaceState.hasError) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: ${workspaceState.error}',
                style: const TextStyle(color: GruvboxColors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GruvboxColors.bg1,
                  foregroundColor: GruvboxColors.fg,
                ),
                onPressed: () => ref.read(workspaceProvider.notifier).refreshWorkspace(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final rootNode = workspaceState.fileTree;
    if (rootNode == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open, size: 48, color: GruvboxColors.gray),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GruvboxColors.bg1,
                  foregroundColor: GruvboxColors.fg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.folder_open, color: GruvboxColors.yellow),
                label: const Text('Open Workspace Folder'),
                onPressed: () {
                  _handleChangeFolder(context);
                },
              ),
            ],
          ),
        ),
      );
    }

    final tags = workspaceState.tags;
    final activeTab = ref.watch(editorProvider).activeTab;
    final sortedChildren = rootNode.sortedChildren.where((node) {
      if (_searchQuery.isEmpty) return true;
      return node.name.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Workspace Header with Compact Buttons and Drop Target for root
        DragTarget<FileNode>(
          onWillAcceptWithDetails: (details) {
            return details.data.uri != rootNode.uri && _getDirname(details.data.uri) != rootNode.uri;
          },
          onAcceptWithDetails: (details) async {
            setState(() {
              _isRootDragHovered = false;
            });
            final incoming = details.data;
            final success = await ref.read(workspaceProvider.notifier).moveNode(incoming.uri, rootNode.uri);
            if (context.mounted && success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: GruvboxColors.bg1,
                  content: Text(
                    'Moved ${incoming.name} to Root',
                    style: const TextStyle(color: GruvboxColors.green),
                  ),
                ),
              );
            }
          },
          onLeave: (_) => setState(() => _isRootDragHovered = false),
          onMove: (_) {
            if (!_isRootDragHovered) setState(() => _isRootDragHovered = true);
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              color: _isRootDragHovered
                  ? GruvboxColors.aqua.withValues(alpha: 0.25)
                  : GruvboxColors.bg1,
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Row(
                children: [
                  const Icon(Icons.folder, color: GruvboxColors.orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Tooltip(
                      message: rootNode.uri,
                      child: Text(
                        rootNode.name,
                        style: const TextStyle(
                          color: GruvboxColors.fg,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // New File at root
                  IconButton(
                    icon: const Icon(Icons.note_add, color: GruvboxColors.aqua, size: 17),
                    tooltip: 'New File',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => _showCreateDialog(context, rootNode.uri, isFolder: false),
                  ),
                  // New Folder at root
                  IconButton(
                    icon: const Icon(Icons.create_new_folder, color: GruvboxColors.yellow, size: 17),
                    tooltip: 'New Folder',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => _showCreateDialog(context, rootNode.uri, isFolder: true),
                  ),
                  // More Actions Menu (Folder switch, refresh)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: GruvboxColors.gray, size: 17),
                    tooltip: 'Workspace Options',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    color: GruvboxColors.bg1,
                    onSelected: (value) {
                      if (value == 'switch_folder') {
                        _handleChangeFolder(context);
                      } else if (value == 'refresh') {
                        ref.read(workspaceProvider.notifier).refreshWorkspace();
                      } else if (value == 'permissions') {
                        ref.read(safStorageServiceProvider).requestStoragePermission();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'switch_folder',
                        child: Row(
                          children: [
                            Icon(Icons.drive_folder_upload, color: GruvboxColors.aqua, size: 16),
                            SizedBox(width: 8),
                            Text('Change Folder...', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, color: GruvboxColors.gray, size: 16),
                            SizedBox(width: 8),
                            Text('Refresh Workspace', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (Platform.isAndroid)
                        const PopupMenuItem(
                          value: 'permissions',
                          child: Row(
                            children: [
                              Icon(Icons.security, color: GruvboxColors.yellow, size: 16),
                              SizedBox(width: 8),
                              Text('All Files Access', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const Divider(color: GruvboxColors.bg3, height: 1),

        // Scrollable tree and tags
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Tree items
              if (sortedChildren.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_open_outlined,
                            size: 36,
                            color: GruvboxColors.gray,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty ? 'No files match "$_searchQuery"' : 'Empty Folder',
                            style: const TextStyle(color: GruvboxColors.gray, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          if (_searchQuery.isEmpty)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GruvboxColors.bg1,
                                foregroundColor: GruvboxColors.aqua,
                              ),
                              icon: const Icon(Icons.note_add, size: 16),
                              label: const Text('Create New File Here'),
                              onPressed: () => _showCreateDialog(context, rootNode.uri, isFolder: false),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return FileTreeItem(
                        node: sortedChildren[index],
                        indentLevel: 0,
                      );
                    },
                    childCount: sortedChildren.length,
                  ),
                ),

              // Tags Section inside scroll view
              const SliverToBoxAdapter(
                child: Divider(color: GruvboxColors.bg3, height: 1),
              ),
              SliverToBoxAdapter(
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
                    title: Row(
                      children: [
                        const Icon(Icons.label, size: 15, color: GruvboxColors.gray),
                        const SizedBox(width: 6),
                        const Text(
                          'Tags',
                          style: TextStyle(
                            color: GruvboxColors.gray,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: GruvboxColors.aqua, size: 17),
                          tooltip: 'Add Tag',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => _showAddTagDialog(context),
                        ),
                      ],
                    ),
                    iconColor: GruvboxColors.gray,
                    collapsedIconColor: GruvboxColors.gray,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 12.0),
                        child: tags.isEmpty
                            ? Row(
                                children: [
                                  const Text(
                                    'No tags. ',
                                    style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                                  ),
                                  InkWell(
                                    onTap: () => _showAddTagDialog(context),
                                    child: const Text(
                                      '+ Add tag',
                                      style: TextStyle(color: GruvboxColors.aqua, fontSize: 12, decoration: TextDecoration.underline),
                                    ),
                                  ),
                                ],
                              )
                            : Wrap(
                                spacing: 4.0,
                                runSpacing: 4.0,
                                children: [
                                  ...tags.map<Widget>((tag) {
                                    final isInActiveFile = activeTab != null &&
                                        ref.read(editorProvider.notifier).activeFileHasTag(tag);

                                    return GestureDetector(
                                      onSecondaryTap: () => _showTagOptions(context, tag),
                                      onLongPress: () => _showTagOptions(context, tag),
                                      child: FilterChip(
                                        visualDensity: VisualDensity.compact,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: EdgeInsets.zero,
                                        label: Text(
                                          '#$tag',
                                          style: TextStyle(
                                            color: isInActiveFile ? GruvboxColors.bgHard : GruvboxColors.fg,
                                            fontSize: 11,
                                            fontWeight: isInActiveFile ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        selected: isInActiveFile,
                                        selectedColor: GruvboxColors.aqua,
                                        backgroundColor: GruvboxColors.bg1,
                                        side: BorderSide(
                                          color: isInActiveFile ? GruvboxColors.aqua : GruvboxColors.bg3,
                                        ),
                                        showCheckmark: true,
                                        checkmarkColor: GruvboxColors.bgHard,
                                        onSelected: (_) {
                                          if (activeTab != null) {
                                            final isNowActive = ref.read(editorProvider.notifier).toggleTagInActiveFile(tag);
                                            if (isNowActive != null) {
                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  backgroundColor: GruvboxColors.bg1,
                                                  duration: const Duration(seconds: 1),
                                                  content: Text(
                                                    isNowActive
                                                        ? 'Added #$tag to ${activeTab.fileName}'
                                                        : 'Removed #$tag from ${activeTab.fileName}',
                                                    style: TextStyle(
                                                      color: isNowActive ? GruvboxColors.green : GruvboxColors.yellow,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                backgroundColor: GruvboxColors.bg1,
                                                duration: Duration(seconds: 1),
                                                content: Text(
                                                  'Open a file to apply this tag.',
                                                  style: TextStyle(color: GruvboxColors.yellow),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  }),
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: EdgeInsets.zero,
                                    avatar: const Icon(Icons.add, size: 13, color: GruvboxColors.aqua),
                                    label: const Text('Add Tag', style: TextStyle(color: GruvboxColors.aqua, fontSize: 11)),
                                    backgroundColor: GruvboxColors.bg1,
                                    side: const BorderSide(color: GruvboxColors.bg3),
                                    onPressed: () => _showAddTagDialog(context),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleChangeFolder(BuildContext context) async {
    final storage = ref.read(safStorageServiceProvider);
    if (Platform.isAndroid) {
      final hasPerm = await storage.hasStoragePermission();
      if (!hasPerm && context.mounted) {
        final grant = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: GruvboxColors.bg1,
            title: const Row(
              children: [
                Icon(Icons.folder_shared, color: GruvboxColors.yellow),
                SizedBox(width: 8),
                Text('Storage Access', style: TextStyle(color: GruvboxColors.fg, fontSize: 16)),
              ],
            ),
            content: const Text(
              'To view and edit folders anywhere on your phone (like Obsidian vaults or Documents), Android requires "All Files Access".\n\nWould you like to grant permission now?',
              style: TextStyle(color: GruvboxColors.fg, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel', style: TextStyle(color: GruvboxColors.gray)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GruvboxColors.aqua,
                  foregroundColor: GruvboxColors.bgHard,
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (grant == true) {
          await storage.requestStoragePermission();
          return;
        }
      }
    }

    if (context.mounted) {
      _showPathChooserDialog(context);
    }
  }

  void _showPathChooserDialog(BuildContext context) {
    final pathController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: const Text('Choose Workspace Folder', style: TextStyle(color: GruvboxColors.fg, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open, color: GruvboxColors.aqua),
                title: const Text('System Folder Picker', style: TextStyle(color: GruvboxColors.fg, fontSize: 14)),
                subtitle: const Text('Browse device storage', style: TextStyle(color: GruvboxColors.gray, fontSize: 11)),
                onTap: () {
                  Navigator.pop(dialogCtx);
                  ref.read(workspaceProvider.notifier).pickAndLoadWorkspace();
                },
              ),
              const Divider(color: GruvboxColors.bg3),
              const SizedBox(height: 6),
              const Text('Or enter/paste folder path:', style: TextStyle(color: GruvboxColors.fg, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: pathController,
                style: const TextStyle(color: GruvboxColors.fg, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: '/storage/emulated/0/Documents/...',
                  hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _quickPathChip(dialogCtx, 'Documents', '/storage/emulated/0/Documents'),
                  _quickPathChip(dialogCtx, 'Downloads', '/storage/emulated/0/Download'),
                  _quickPathChip(dialogCtx, 'Obsidian', '/storage/emulated/0/Documents/Obsidian'),
                  _quickPathChip(dialogCtx, 'QuillPapyrus', '/storage/emulated/0/Documents/QuillPapyrus'),
                ],
              ),
            ],
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
              final path = pathController.text.trim();
              if (path.isNotEmpty) {
                Navigator.pop(dialogCtx);
                ref.read(workspaceProvider.notifier).loadWorkspace(path);
              }
            },
            child: const Text('Open Path'),
          ),
        ],
      ),
    );
  }

  Widget _quickPathChip(BuildContext dialogCtx, String label, String path) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(color: GruvboxColors.fg, fontSize: 11)),
      backgroundColor: GruvboxColors.bg2,
      onPressed: () {
        Navigator.pop(dialogCtx);
        ref.read(workspaceProvider.notifier).loadWorkspace(path);
      },
    );
  }

  String _getDirname(String path) {
    final lastSep = path.lastIndexOf(RegExp(r'[/\\]'));
    if (lastSep > 0) return path.substring(0, lastSep);
    return path;
  }

  void _showCreateDialog(BuildContext context, String parentUri, {required bool isFolder}) {
    final controller = TextEditingController(text: isFolder ? '' : 'NewDocument.md');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: Text(
          isFolder ? 'Create Folder' : 'Create New Markdown File',
          style: const TextStyle(color: GruvboxColors.fg),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: GruvboxColors.fg),
          decoration: InputDecoration(
            hintText: isFolder ? 'Folder name' : 'File name (e.g. Note.md)',
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
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (isFolder) {
                  await ref.read(workspaceProvider.notifier).createDirectory(parentUri, name);
                } else {
                  final newUri = await ref.read(workspaceProvider.notifier).createFile(parentUri, name);
                  if (newUri != null) {
                    ref.read(editorProvider.notifier).openFile(newUri, name);
                  }
                }
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

  void _showAddTagDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: const Text('Add Tag', style: TextStyle(color: GruvboxColors.fg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: GruvboxColors.fg),
          decoration: const InputDecoration(
            hintText: 'Tag name (e.g. project, notes)',
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
            onPressed: () {
              final tag = controller.text.trim();
              if (tag.isNotEmpty) {
                ref.read(workspaceProvider.notifier).addWorkspaceTag(tag);
                final activeTab = ref.read(editorProvider).activeTab;
                if (activeTab != null) {
                  ref.read(editorProvider.notifier).toggleTagInActiveFile(tag);
                }
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showTagOptions(BuildContext context, String tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GruvboxColors.bg1,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.label, color: GruvboxColors.aqua),
              title: Text('#$tag', style: const TextStyle(color: GruvboxColors.fg, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: GruvboxColors.blue),
              title: const Text('Rename Tag', style: TextStyle(color: GruvboxColors.fg)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showRenameTagDialog(context, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: GruvboxColors.red),
              title: const Text('Delete Tag', style: TextStyle(color: GruvboxColors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                ref.read(workspaceProvider.notifier).deleteWorkspaceTag(tag);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameTagDialog(BuildContext context, String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: const Text('Rename Tag', style: TextStyle(color: GruvboxColors.fg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: GruvboxColors.fg),
          decoration: const InputDecoration(
            hintText: 'New tag name',
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
              final newTag = controller.text.trim();
              if (newTag.isNotEmpty && newTag != oldTag) {
                ref.read(workspaceProvider.notifier).updateWorkspaceTag(oldTag, newTag);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
