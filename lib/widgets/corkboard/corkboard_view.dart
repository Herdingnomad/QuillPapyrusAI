import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/file_node.dart';
import 'package:quill_papyrus_ai/models/manuscript_metadata.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/app_materials.dart';
import 'package:quill_papyrus_ai/theme/app_typography.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';
import 'package:quill_papyrus_ai/widgets/common/atelier_marks.dart';

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
        return GruvboxColors.fgMuted;
      case SceneDraftStatus.draft:
        return GruvboxColors.accent;
      case SceneDraftStatus.revised:
        return GruvboxColors.orange;
      case SceneDraftStatus.polished:
        return GruvboxColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = GruvboxColors.activeTheme.isDark;

    if (_isLoading) {
      return ColoredBox(
        color: GruvboxColors.bgHard,
        child: Center(
          child: CircularProgressIndicator(color: GruvboxColors.accent, strokeWidth: 2),
        ),
      );
    }

    if (_files.isEmpty) {
      return ColoredBox(
        color: GruvboxColors.bgHard,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FountainNibMark(size: 32, color: GruvboxColors.fgMuted),
                const SizedBox(height: 12),
                Text(
                  'No markdown scenes in this folder',
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle(GruvboxColors.fg, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create `.md` files in "${widget.folderNode.name}" to arrange archival index cards.',
                  textAlign: TextAlign.center,
                  style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: GruvboxColors.bgHard,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _files.length,
        onReorderItem: _onReorder,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(animation.value);
              return Transform.scale(
                scale: 1.0 + (0.024 * t),
                child: Material(
                  color: Colors.transparent,
                  elevation: 10 * t,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                ),
              );
            },
          );
        },
        itemBuilder: (context, index) {
          final file = _files[index];
          final meta = _metadataMap[file.uri] ?? ManuscriptMetadata(title: file.name);
          final wordCount = _wordCountMap[file.uri] ?? 0;
          return _buildIndexCard(file, meta, wordCount, index, isDark: isDark);
        },
      ),
    );
  }

  /// Archival unruled cotton-rag 3x5 index card (4% visible parchment fiber, NO ruled horizontal lines).
  Widget _buildIndexCard(
    FileNode file,
    ManuscriptMetadata meta,
    int wordCount,
    int index, {
    required bool isDark,
  }) {
    final statusColor = _getStatusColor(meta.status);

    return Container(
      key: ValueKey(file.uri),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: GruvboxColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GruvboxColors.hairlineBorder, width: 0.85),
        boxShadow: AppMaterials.paperSheetShadows(isDark: isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: PaperGrainSurface(
        intensity: 0.04,
        backgroundColor: GruvboxColors.bg,
        isDark: isDark,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ref.read(editorProvider.notifier).openFile(file.uri, file.name);
            },
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top card header: Rubber-stamp status badge, POV, Timeline, Grip
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3.5),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.45),
                            width: 0.75,
                          ),
                        ),
                        child: Text(
                          meta.status.label.toUpperCase(),
                          style: AppTypography.uiLabel(
                            statusColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ).copyWith(letterSpacing: 0.8),
                        ),
                      ),
                      if (meta.pov != null && meta.pov!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: GruvboxColors.bg1.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3.5),
                              border: Border.all(color: GruvboxColors.subtleDivider, width: 0.65),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 11, color: GruvboxColors.fgMuted),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    meta.pov!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.uiLabel(
                                      GruvboxColors.fg2,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (meta.timeline != null && meta.timeline!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            meta.timeline!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.uiLabel(GruvboxColors.fgMuted, fontSize: 10.5),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(
                        Icons.drag_indicator_rounded,
                        color: GruvboxColors.fgMuted.withValues(alpha: 0.65),
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Editorial Serif Scene Title
                  Text(
                    meta.title.isNotEmpty ? meta.title : file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sectionTitle(
                      GruvboxColors.fg0,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Unruled Synopsis Body
                  Text(
                    meta.synopsis != null && meta.synopsis!.isNotEmpty
                        ? meta.synopsis!
                        : 'No synopsis recorded yet. Open scene to compose notes.',
                    style: EditorFontFamily.literaryProse
                        .previewBodyStyle(
                          color: meta.synopsis != null && meta.synopsis!.isNotEmpty
                              ? GruvboxColors.fg2
                              : GruvboxColors.fgMuted,
                          fontSizeOverride: 13.0,
                        )
                        .copyWith(
                          height: 1.48,
                          fontStyle:
                              meta.synopsis == null ? FontStyle.italic : FontStyle.normal,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Colophon Footer: Tabular Word Count & Target Progress
                  Row(
                    children: [
                      Text(
                        'SCENE ${(index + 1).toString().padLeft(2, '0')}',
                        style: AppTypography.tabularMetric(
                          GruvboxColors.fgMuted.withValues(alpha: 0.7),
                          fontSize: 10,
                        ).copyWith(letterSpacing: 0.7),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$wordCount words',
                        style: AppTypography.tabularMetric(
                          GruvboxColors.fgMuted,
                          fontSize: 11,
                        ),
                      ),
                      if (meta.targetWords != null && meta.targetWords! > 0) ...[
                        Text(
                          ' / ${meta.targetWords}',
                          style: AppTypography.tabularMetric(
                            GruvboxColors.fgMuted.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (wordCount / meta.targetWords!).clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: GruvboxColors.bg2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                wordCount >= meta.targetWords!
                                    ? GruvboxColors.green
                                    : GruvboxColors.accent,
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
        ),
      ),
    );
  }
}
