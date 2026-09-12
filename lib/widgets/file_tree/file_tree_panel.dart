import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/workspace_state.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/layout_provider.dart';
import 'package:quill_papyrus_ai/providers/tag_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/template_generator_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/template_manager_dialog.dart';
import 'package:quill_papyrus_ai/widgets/dialogs/theme_manager_dialog.dart';
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

  bool _isCloseMatch(String target, String query) {
    if (query.isEmpty) return true;
    final t = target.toLowerCase();
    final q = query.toLowerCase();
    if (t.contains(q) || q.contains(t)) return true;

    final targetNormalized = t.replaceAll(RegExp(r'[-_]'), ' ');
    final queryNormalized = q.replaceAll(RegExp(r'[-_]'), ' ');
    if (targetNormalized.contains(queryNormalized) || queryNormalized.contains(targetNormalized)) {
      return true;
    }

    if (q.length >= 3) {
      var tIdx = 0;
      var qIdx = 0;
      while (tIdx < t.length && qIdx < q.length) {
        if (t[tIdx] == q[qIdx]) {
          qIdx++;
        }
        tIdx++;
      }
      if (qIdx == q.length) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = ref.watch(workspaceProvider);

    return Material(
      color: GruvboxColors.bgHard,
      child: Column(
        children: [
          // Top section: Search bar & Collapse button
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 4.0, 4.0),
            child: Row(
              children: [
                Expanded(
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
                      hintText: 'Search files, tags, topics...',
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
                IconButton(
                  icon: const Icon(Icons.first_page, color: GruvboxColors.gray, size: 20),
                  tooltip: 'Hide Explorer (Ctrl+B)',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => ref.read(layoutProvider.notifier).setLeftPaneVisible(false),
                ),
              ],
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
    final topics = workspaceState.topics;
    final activeTab = ref.watch(editorProvider).activeTab;
    final activeTag = ref.watch(activeTagFilterProvider);
    final activeTopic = ref.watch(activeTopicFilterProvider);

    // Parse search query for tag: or topic: syntax
    String? searchTag;
    String? searchTopic;
    final rawQuery = _searchQuery.trim();
    String textQuery = rawQuery;

    if (textQuery.startsWith('#')) {
      searchTag = textQuery.substring(1).trim();
      textQuery = '';
    } else if (textQuery.startsWith('tag:')) {
      searchTag = textQuery.substring(4).trim();
      textQuery = '';
    } else if (textQuery.startsWith('@')) {
      searchTopic = textQuery.substring(1).trim();
      textQuery = '';
    } else if (textQuery.startsWith('topic:')) {
      searchTopic = textQuery.substring(6).trim();
      textQuery = '';
    }

    final isFiltered = activeTag != null || activeTopic != null || rawQuery.isNotEmpty;

    final allFiles = _flattenFiles(rootNode);
    final matchingFiles = isFiltered
        ? allFiles.where((node) {
            if (node.isDirectory) return false;
            if (activeTag != null) {
              final uris = workspaceState.tagIndex[activeTag] ?? [];
              if (!uris.contains(node.uri)) return false;
            }
            if (activeTopic != null) {
              final uris = workspaceState.topicIndex[activeTopic] ?? [];
              if (!uris.contains(node.uri)) return false;
            }
            if (searchTag != null && searchTag.isNotEmpty) {
              final hasMatchingTag = workspaceState.tagIndex.entries.any(
                (e) => _isCloseMatch(e.key, searchTag!) && e.value.contains(node.uri),
              );
              if (!hasMatchingTag) return false;
            }
            if (searchTopic != null && searchTopic.isNotEmpty) {
              final hasMatchingTopic = workspaceState.topicIndex.entries.any(
                (e) => _isCloseMatch(e.key, searchTopic!) && e.value.contains(node.uri),
              );
              if (!hasMatchingTopic) return false;
            }
            if (textQuery.isNotEmpty) {
              final matchesFileName = _isCloseMatch(node.name, textQuery);
              final matchesTag = workspaceState.tagIndex.entries.any(
                (e) => e.value.contains(node.uri) && _isCloseMatch(e.key, textQuery),
              );
              final matchesTopic = workspaceState.topicIndex.entries.any(
                (e) => e.value.contains(node.uri) && _isCloseMatch(e.key, textQuery),
              );

              if (!matchesFileName && !matchesTag && !matchesTopic) {
                return false;
              }
            }
            return true;
          }).toList()
        : const <FileNode>[];

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
                  // Daily Journal Entry Quick Creator
                  IconButton(
                    icon: const Icon(Icons.today, color: GruvboxColors.green, size: 17),
                    tooltip: "New Today's Journal Entry",
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => _createDailyJournal(context),
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
                  // Document Templates Library
                  IconButton(
                    icon: const Icon(Icons.style_outlined, color: GruvboxColors.aqua, size: 17),
                    tooltip: 'Document Templates',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => showTemplateManagerDialog(context, ref),
                  ),
                  // More Actions Menu (Folder switch, refresh)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: GruvboxColors.gray, size: 17),
                    tooltip: 'Workspace Options',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    color: GruvboxColors.bg1,
                    onSelected: (value) {
                      if (value == 'journal') {
                        _createDailyJournal(context);
                      } else if (value == 'templates') {
                        showTemplateManagerDialog(context, ref);
                      } else if (value == 'themes') {
                        showThemeManagerDialog(context, ref);
                      } else if (value == 'ai_template') {
                        showTemplateGeneratorDialog(context, ref);
                      } else if (value == 'switch_folder') {
                        _handleChangeFolder(context);
                      } else if (value == 'refresh') {
                        ref.read(workspaceProvider.notifier).refreshWorkspace();
                      } else if (value == 'permissions') {
                        ref.read(safStorageServiceProvider).requestStoragePermission();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'journal',
                        child: Row(
                          children: [
                            Icon(Icons.today, color: GruvboxColors.green, size: 16),
                            SizedBox(width: 8),
                            Text("New Today's Entry", style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'templates',
                        child: Row(
                          children: [
                            Icon(Icons.style_outlined, color: GruvboxColors.aqua, size: 16),
                            SizedBox(width: 8),
                            Text('Document Templates (CRUD)...', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'themes',
                        child: Row(
                          children: [
                            Icon(Icons.palette_outlined, color: GruvboxColors.yellow, size: 16),
                            SizedBox(width: 8),
                            Text('Color Themes (Hex CRUD)...', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'ai_template',
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, color: GruvboxColors.yellow, size: 16),
                            SizedBox(width: 8),
                            Text('AI Document Template...', style: TextStyle(color: GruvboxColors.fg, fontSize: 13)),
                          ],
                        ),
                      ),
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
              if (isFiltered) ...[
                // Filter active header banner
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: GruvboxColors.bg2,
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: GruvboxColors.bg3),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 14, color: GruvboxColors.aqua),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Wrap(
                            spacing: 4.0,
                            runSpacing: 2.0,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (activeTag != null)
                                InputChip(
                                  visualDensity: VisualDensity.compact,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: EdgeInsets.zero,
                                  label: Text('#$activeTag',
                                      style: const TextStyle(
                                          color: GruvboxColors.aqua, fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: GruvboxColors.bgHard,
                                  deleteIconColor: GruvboxColors.aqua,
                                  onDeleted: () => ref.read(activeTagFilterProvider.notifier).state = null,
                                ),
                              if (activeTopic != null)
                                InputChip(
                                  visualDensity: VisualDensity.compact,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: EdgeInsets.zero,
                                  label: Text('@$activeTopic',
                                      style: const TextStyle(
                                          color: GruvboxColors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: GruvboxColors.bgHard,
                                  deleteIconColor: GruvboxColors.purple,
                                  onDeleted: () => ref.read(activeTopicFilterProvider.notifier).state = null,
                                ),
                              if (searchTag != null && searchTag.isNotEmpty)
                                Text('tag: $searchTag', style: const TextStyle(color: GruvboxColors.aqua, fontSize: 11)),
                              if (searchTopic != null && searchTopic.isNotEmpty)
                                Text('topic: $searchTopic', style: const TextStyle(color: GruvboxColors.purple, fontSize: 11)),
                              if (textQuery.isNotEmpty && searchTag == null && searchTopic == null)
                                Text('"$textQuery"', style: const TextStyle(color: GruvboxColors.aqua, fontSize: 11, fontStyle: FontStyle.italic)),
                              Text(
                                '(${matchingFiles.length} file${matchingFiles.length == 1 ? "" : "s"})',
                                style: const TextStyle(color: GruvboxColors.gray, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: GruvboxColors.gray),
                          tooltip: 'Clear filter',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            ref.read(activeTagFilterProvider.notifier).state = null;
                            ref.read(activeTopicFilterProvider.notifier).state = null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Matching documents list
                if (matchingFiles.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.search_off, size: 36, color: GruvboxColors.gray),
                            const SizedBox(height: 8),
                            const Text(
                              'No documents match this filter',
                              style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GruvboxColors.bg1,
                                foregroundColor: GruvboxColors.aqua,
                              ),
                              icon: const Icon(Icons.clear, size: 14),
                              label: const Text('Show All Documents', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                ref.read(activeTagFilterProvider.notifier).state = null;
                                ref.read(activeTopicFilterProvider.notifier).state = null;
                              },
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
                        final fileNode = matchingFiles[index];
                        final isSelected = activeTab?.uri == fileNode.uri;
                        final parentDir = _getParentFolderName(fileNode.uri, rootNode.uri);

                        final fileTags = workspaceState.tagIndex.entries
                            .where((e) => e.value.contains(fileNode.uri))
                            .map((e) => e.key)
                            .toList();
                        final fileTopics = workspaceState.topicIndex.entries
                            .where((e) => e.value.contains(fileNode.uri))
                            .map((e) => e.key)
                            .toList();

                        return InkWell(
                          onTap: () => ref.read(editorProvider.notifier).openFile(fileNode.uri, fileNode.name),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? GruvboxColors.aqua.withValues(alpha: 0.12) : Colors.transparent,
                              border: Border(
                                bottom: const BorderSide(color: GruvboxColors.bg1, width: 1),
                                left: isSelected
                                    ? const BorderSide(color: GruvboxColors.aqua, width: 3)
                                    : BorderSide.none,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      fileNode.name.endsWith('.md') ? Icons.description : Icons.insert_drive_file,
                                      size: 15,
                                      color: isSelected ? GruvboxColors.aqua : GruvboxColors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        fileNode.name,
                                        style: TextStyle(
                                          color: isSelected ? GruvboxColors.aqua : GruvboxColors.fg,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (parentDir.isNotEmpty)
                                      Text(
                                        parentDir,
                                        style: const TextStyle(color: GruvboxColors.gray, fontSize: 10),
                                      ),
                                  ],
                                ),
                                if (fileTags.isNotEmpty || fileTopics.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: [
                                      ...fileTags.map((t) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: t == activeTag
                                                  ? GruvboxColors.aqua.withValues(alpha: 0.25)
                                                  : GruvboxColors.bg2,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              '#$t',
                                              style: TextStyle(
                                                color: t == activeTag ? GruvboxColors.aqua : GruvboxColors.fg4,
                                                fontSize: 9,
                                                fontWeight: t == activeTag ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          )),
                                      ...fileTopics.map((top) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: top == activeTopic
                                                  ? GruvboxColors.purple.withValues(alpha: 0.25)
                                                  : GruvboxColors.bg2,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              '@$top',
                                              style: TextStyle(
                                                color: top == activeTopic ? GruvboxColors.purple : GruvboxColors.fg4,
                                                fontSize: 9,
                                                fontWeight: top == activeTopic ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          )),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: matchingFiles.length,
                    ),
                  ),
              ] else ...[
                // Standard Folder Tree
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
              ],

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
                        const Icon(Icons.label, size: 15, color: GruvboxColors.aqua),
                        const SizedBox(width: 6),
                        Text(
                          'Tags (${tags.length})',
                          style: const TextStyle(
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
                        padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 8.0),
                        child: tags.isEmpty
                            ? Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
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
                                    final isFilterActive = activeTag == tag;
                                    final docCount = workspaceState.tagIndex[tag]?.length ?? 0;

                                    return GestureDetector(
                                      onSecondaryTap: () => _showTagOptions(context, tag),
                                      onLongPress: () => _showTagOptions(context, tag),
                                      child: FilterChip(
                                        visualDensity: VisualDensity.compact,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: EdgeInsets.zero,
                                        label: Text(
                                          '#$tag ($docCount)',
                                          style: TextStyle(
                                            color: isFilterActive ? GruvboxColors.bgHard : GruvboxColors.fg,
                                            fontSize: 11,
                                            fontWeight: isFilterActive ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        selected: isFilterActive,
                                        selectedColor: GruvboxColors.aqua,
                                        backgroundColor: GruvboxColors.bg1,
                                        side: BorderSide(
                                          color: isFilterActive ? GruvboxColors.aqua : GruvboxColors.bg3,
                                        ),
                                        showCheckmark: true,
                                        checkmarkColor: GruvboxColors.bgHard,
                                        onSelected: (_) {
                                          final newFilter = isFilterActive ? null : tag;
                                          ref.read(activeTagFilterProvider.notifier).state = newFilter;
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

              // Topics Section inside scroll view
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
                        const Icon(Icons.category_outlined, size: 15, color: GruvboxColors.purple),
                        const SizedBox(width: 6),
                        Text(
                          'Topics (${topics.length})',
                          style: const TextStyle(
                            color: GruvboxColors.gray,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: GruvboxColors.purple, size: 17),
                          tooltip: 'Add Topic',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => _showAddTopicDialog(context),
                        ),
                      ],
                    ),
                    iconColor: GruvboxColors.gray,
                    collapsedIconColor: GruvboxColors.gray,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 12.0),
                        child: topics.isEmpty
                            ? Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'No topics. ',
                                    style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                                  ),
                                  InkWell(
                                    onTap: () => _showAddTopicDialog(context),
                                    child: const Text(
                                      '+ Add topic',
                                      style: TextStyle(color: GruvboxColors.purple, fontSize: 12, decoration: TextDecoration.underline),
                                    ),
                                  ),
                                ],
                              )
                            : Wrap(
                                spacing: 4.0,
                                runSpacing: 4.0,
                                children: [
                                  ...topics.map<Widget>((topic) {
                                    final isFilterActive = activeTopic == topic;
                                    final docCount = workspaceState.topicIndex[topic]?.length ?? 0;

                                    return GestureDetector(
                                      onSecondaryTap: () => _showTopicOptions(context, topic),
                                      onLongPress: () => _showTopicOptions(context, topic),
                                      child: FilterChip(
                                        visualDensity: VisualDensity.compact,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                        padding: EdgeInsets.zero,
                                        label: Text(
                                          '@$topic ($docCount)',
                                          style: TextStyle(
                                            color: isFilterActive ? GruvboxColors.bgHard : GruvboxColors.fg,
                                            fontSize: 11,
                                            fontWeight: isFilterActive ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        selected: isFilterActive,
                                        selectedColor: GruvboxColors.purple,
                                        backgroundColor: GruvboxColors.bg1,
                                        side: BorderSide(
                                          color: isFilterActive ? GruvboxColors.purple : GruvboxColors.bg3,
                                        ),
                                        showCheckmark: true,
                                        checkmarkColor: GruvboxColors.bgHard,
                                        onSelected: (_) {
                                          final newFilter = isFilterActive ? null : topic;
                                          ref.read(activeTopicFilterProvider.notifier).state = newFilter;
                                        },
                                      ),
                                    );
                                  }),
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: EdgeInsets.zero,
                                    avatar: const Icon(Icons.add, size: 13, color: GruvboxColors.purple),
                                    label: const Text('Add Topic', style: TextStyle(color: GruvboxColors.purple, fontSize: 11)),
                                    backgroundColor: GruvboxColors.bg1,
                                    side: const BorderSide(color: GruvboxColors.bg3),
                                    onPressed: () => _showAddTopicDialog(context),
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

  List<FileNode> _flattenFiles(FileNode node) {
    final List<FileNode> files = [];
    void collect(FileNode n) {
      if (n.isDirectory) {
        for (final child in n.children) {
          collect(child);
        }
      } else {
        files.add(n);
      }
    }
    collect(node);
    return files;
  }

  String _getParentFolderName(String fileUri, String rootUri) {
    final lastSep = fileUri.lastIndexOf(RegExp(r'[/\\]'));
    if (lastSep <= 0) return '';
    final dir = fileUri.substring(0, lastSep);
    if (dir == rootUri) return '';
    final dirSep = dir.lastIndexOf(RegExp(r'[/\\]'));
    if (dirSep != -1) {
      return dir.substring(dirSep + 1);
    }
    return dir;
  }

  Future<void> _createDailyJournal(BuildContext context) async {
    final newUri = await ref.read(workspaceProvider.notifier).createDailyJournalEntry();
    if (newUri != null && context.mounted) {
      final lastSep = newUri.lastIndexOf(RegExp(r'[/\\]'));
      final name = lastSep != -1 ? newUri.substring(lastSep + 1) : newUri;
      ref.read(editorProvider.notifier).openFile(newUri, name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GruvboxColors.bg1,
          content: Text('Created $name with YAML Frontmatter', style: const TextStyle(color: GruvboxColors.green)),
        ),
      );
    }
  }

  void _showTagOptions(BuildContext context, String tag) {
    final activeTab = ref.read(editorProvider).activeTab;
    final hasInActive = activeTab != null && ref.read(editorProvider.notifier).activeFileHasTag(tag);
    final count = ref.read(workspaceProvider).tagIndex[tag]?.length ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: GruvboxColors.bg1,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.label, color: GruvboxColors.aqua),
              title: Text('#$tag', style: const TextStyle(color: GruvboxColors.fg, fontWeight: FontWeight.bold)),
              subtitle: Text('$count document${count == 1 ? "" : "s"}',
                  style: const TextStyle(color: GruvboxColors.gray, fontSize: 11)),
            ),
            ListTile(
              leading: const Icon(Icons.filter_list, color: GruvboxColors.aqua),
              title: Text('Filter documents by #$tag', style: const TextStyle(color: GruvboxColors.fg)),
              onTap: () {
                Navigator.pop(sheetCtx);
                ref.read(activeTagFilterProvider.notifier).state = tag;
              },
            ),
            if (activeTab != null)
              ListTile(
                leading: Icon(hasInActive ? Icons.label_off : Icons.new_label,
                    color: hasInActive ? GruvboxColors.yellow : GruvboxColors.green),
                title: Text(
                  hasInActive ? 'Remove #$tag from ${activeTab.fileName}' : 'Add #$tag to ${activeTab.fileName}',
                  style: const TextStyle(color: GruvboxColors.fg),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ref.read(editorProvider.notifier).toggleTagInActiveFile(tag);
                },
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
                if (ref.read(activeTagFilterProvider) == tag) {
                  ref.read(activeTagFilterProvider.notifier).state = null;
                }
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

  void _showAddTopicDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: const Text('Add Topic', style: TextStyle(color: GruvboxColors.fg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: GruvboxColors.fg),
          decoration: const InputDecoration(
            hintText: 'Topic name (e.g. writing, app_testing)',
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
              backgroundColor: GruvboxColors.purple,
              foregroundColor: GruvboxColors.bgHard,
            ),
            onPressed: () {
              final topic = controller.text.trim();
              if (topic.isNotEmpty) {
                ref.read(workspaceProvider.notifier).addWorkspaceTopic(topic);
                final activeTab = ref.read(editorProvider).activeTab;
                if (activeTab != null) {
                  ref.read(editorProvider.notifier).toggleTopicInActiveFile(topic);
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

  void _showTopicOptions(BuildContext context, String topic) {
    final activeTab = ref.read(editorProvider).activeTab;
    final hasInActive = activeTab != null && ref.read(editorProvider.notifier).activeFileHasTopic(topic);
    final count = ref.read(workspaceProvider).topicIndex[topic]?.length ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: GruvboxColors.bg1,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.category, color: GruvboxColors.purple),
              title: Text('@$topic', style: const TextStyle(color: GruvboxColors.fg, fontWeight: FontWeight.bold)),
              subtitle: Text('$count document${count == 1 ? "" : "s"}',
                  style: const TextStyle(color: GruvboxColors.gray, fontSize: 11)),
            ),
            ListTile(
              leading: const Icon(Icons.filter_list, color: GruvboxColors.purple),
              title: Text('Filter documents by topic: $topic', style: const TextStyle(color: GruvboxColors.fg)),
              onTap: () {
                Navigator.pop(sheetCtx);
                ref.read(activeTopicFilterProvider.notifier).state = topic;
              },
            ),
            if (activeTab != null)
              ListTile(
                leading: Icon(hasInActive ? Icons.category : Icons.add_circle,
                    color: hasInActive ? GruvboxColors.yellow : GruvboxColors.green),
                title: Text(
                  hasInActive ? 'Remove @$topic from ${activeTab.fileName}' : 'Add @$topic to ${activeTab.fileName}',
                  style: const TextStyle(color: GruvboxColors.fg),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ref.read(editorProvider.notifier).toggleTopicInActiveFile(topic);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit, color: GruvboxColors.blue),
              title: const Text('Rename Topic', style: TextStyle(color: GruvboxColors.fg)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showRenameTopicDialog(context, topic);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: GruvboxColors.red),
              title: const Text('Delete Topic', style: TextStyle(color: GruvboxColors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                ref.read(workspaceProvider.notifier).deleteWorkspaceTopic(topic);
                if (ref.read(activeTopicFilterProvider) == topic) {
                  ref.read(activeTopicFilterProvider.notifier).state = null;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameTopicDialog(BuildContext context, String oldTopic) {
    final controller = TextEditingController(text: oldTopic);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GruvboxColors.bg1,
        title: const Text('Rename Topic', style: TextStyle(color: GruvboxColors.fg)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: GruvboxColors.fg),
          decoration: const InputDecoration(
            hintText: 'New topic name',
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
              backgroundColor: GruvboxColors.purple,
              foregroundColor: GruvboxColors.bgHard,
            ),
            onPressed: () {
              final newTopic = controller.text.trim();
              if (newTopic.isNotEmpty && newTopic != oldTopic) {
                ref.read(workspaceProvider.notifier).updateWorkspaceTopic(oldTopic, newTopic);
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
