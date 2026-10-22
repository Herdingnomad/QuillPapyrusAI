import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/manuscript_metadata.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class CorkboardView extends ConsumerStatefulWidget {
  final FileNode folderNode;

  const CorkboardView({
    super.key,
    required this.folderNode,
  });

  @override
  ConsumerState<CorkboardView> createState() => _CorkboardViewState();
}

class _CorkboardViewState extends ConsumerState<CorkboardView> {
  List<FileNode> _files = [];
  final Map<String, ManuscriptMetadata> _metadataMap = {};
  final Map<String, int> _wordCountMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  @override
  void didUpdateWidget(covariant CorkboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderNode.uri != widget.folderNode.uri) {
      _loadCards();
    }
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final storage = ref.read(safStorageServiceProvider);
    final markdownFiles = widget.folderNode.children
        .where((c) => !c.isDirectory && (c.name.endsWith('.md') || c.name.endsWith('.markdown')))
        .toList();

    _metadataMap.clear();
    _wordCountMap.clear();

    for (final file in markdownFiles) {
      try {
        final content = await storage.readFile(file.uri);
        final meta = ManuscriptMetadata.extractFromMarkdown(content, fallbackTitle: file.name);
        _metadataMap[file.uri] = meta;
        final words = content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;
        _wordCountMap[file.uri] = words;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _files = markdownFiles;
        _isLoading = false;
      });
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _files.removeAt(oldIndex);
      _files.insert(newIndex, item);
    });
  }

  Color _getStatusColor(SceneDraftStatus status) {
    switch (status) {
      case SceneDraftStatus.idea:
        return GruvboxColors.blue;
      case SceneDraftStatus.draft:
        return GruvboxColors.yellow;
      case SceneDraftStatus.revised:
        return GruvboxColors.orange;
      case SceneDraftStatus.polished:
        return GruvboxColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: GruvboxColors.bgHard,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_files.isEmpty) {
      return Container(
        color: GruvboxColors.bgHard,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dashboard_outlined, size: 48, color: GruvboxColors.gray),
              const SizedBox(height: 12),
              Text(
                'No markdown scenes in this folder',
                style: TextStyle(color: GruvboxColors.gray, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: GruvboxColors.bgHard,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _files.length,
        onReorderItem: _onReorder,
        itemBuilder: (context, index) {
          final file = _files[index];
          final meta = _metadataMap[file.uri] ?? ManuscriptMetadata(title: file.name);
          final wordCount = _wordCountMap[file.uri] ?? 0;
          return _buildIndexCard(file, meta, wordCount, index);
        },
      ),
    );
  }

  Widget _buildIndexCard(FileNode file, ManuscriptMetadata meta, int wordCount, int index) {
    final statusColor = _getStatusColor(meta.status);

    return Card(
      key: ValueKey(file.uri),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      color: GruvboxColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: GruvboxColors.bg3, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ref.read(editorProvider.notifier).openFile(file.uri, file.name);
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top card header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      meta.status.label.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (meta.pov != null && meta.pov!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: GruvboxColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 11, color: GruvboxColors.purple),
                          const SizedBox(width: 3),
                          Text(
                            meta.pov!,
                            style: TextStyle(
                              color: GruvboxColors.purple,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (meta.timeline != null && meta.timeline!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      meta.timeline!,
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.drag_handle, color: GruvboxColors.gray, size: 18),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                meta.title.isNotEmpty ? meta.title : file.name,
                style: TextStyle(
                  color: GruvboxColors.fg0,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              // Synopsis
              Text(
                meta.synopsis != null && meta.synopsis!.isNotEmpty
                    ? meta.synopsis!
                    : 'No synopsis entered yet. Click to open and add scene synopsis.',
                style: TextStyle(
                  color: meta.synopsis != null && meta.synopsis!.isNotEmpty
                      ? GruvboxColors.fg
                      : GruvboxColors.gray,
                  fontSize: 12,
                  fontStyle: meta.synopsis == null ? FontStyle.italic : FontStyle.normal,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Bottom footer: word count, target, progress
              Row(
                children: [
                  Icon(Icons.notes, size: 13, color: GruvboxColors.gray),
                  const SizedBox(width: 4),
                  Text(
                    '$wordCount words',
                    style: TextStyle(
                      color: GruvboxColors.gray,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meta.targetWords != null && meta.targetWords! > 0) ...[
                    Text(
                      ' / ${meta.targetWords} target',
                      style: TextStyle(color: GruvboxColors.gray, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (wordCount / meta.targetWords!).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: GruvboxColors.bg2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            wordCount >= meta.targetWords! ? GruvboxColors.green : GruvboxColors.yellow,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
