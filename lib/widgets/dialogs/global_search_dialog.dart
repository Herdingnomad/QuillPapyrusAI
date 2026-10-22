import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_papyrus_ai/models/search_models.dart';
import 'package:quill_papyrus_ai/providers/editor_provider.dart';
import 'package:quill_papyrus_ai/providers/find_replace_provider.dart';
import 'package:quill_papyrus_ai/providers/workspace_provider.dart';
import 'package:quill_papyrus_ai/theme/gruvbox_theme.dart';

class GlobalSearchDialog extends ConsumerStatefulWidget {
  const GlobalSearchDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const GlobalSearchDialog(),
    );
  }

  @override
  ConsumerState<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<GlobalSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    final root = ref.read(workspaceProvider).rootUri;
    if (root == null) return;
    ref.read(findReplaceProvider.notifier).performGlobalSearch(
          _queryController.text.trim(),
          root,
        );
  }

  @override
  Widget build(BuildContext context) {
    final findState = ref.watch(findReplaceProvider);
    final results = findState.globalResults;
    final isSearching = findState.isGlobalSearching;

    return Dialog(
      backgroundColor: GruvboxColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: GruvboxColors.bg3),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.manage_search, color: GruvboxColors.yellow, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Search Entire Workspace',
                    style: TextStyle(
                      color: GruvboxColors.fg,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: GruvboxColors.gray, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: GruvboxColors.bg1,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GruvboxColors.bg3),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _queryController,
                        focusNode: _focusNode,
                        style: TextStyle(color: GruvboxColors.fg, fontSize: 14),
                        cursorColor: GruvboxColors.yellow,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search words, character names, or regex in manuscript...',
                          hintStyle: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: GruvboxColors.gray, size: 18),
                        ),
                        onSubmitted: (_) => _triggerSearch(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GruvboxColors.yellow,
                      foregroundColor: GruvboxColors.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Search'),
                    onPressed: _triggerSearch,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Results summary
              if (isSearching)
                const LinearProgressIndicator(minHeight: 2)
              else if (_queryController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Found ${results.fold<int>(0, (sum, r) => sum + r.matchCount)} matches across ${results.length} files',
                    style: TextStyle(color: GruvboxColors.gray, fontSize: 12),
                  ),
                ),

              // Results List
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          _queryController.text.isEmpty
                              ? 'Enter a term to search all chapters and notes'
                              : isSearching
                                  ? 'Searching...'
                                  : 'No matches found',
                          style: TextStyle(color: GruvboxColors.gray, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          return _buildFileResultCard(context, item);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileResultCard(BuildContext context, WorkspaceSearchResult fileResult) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: GruvboxColors.bg1,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GruvboxColors.bg3),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        collapsedIconColor: GruvboxColors.gray,
        iconColor: GruvboxColors.aqua,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        title: Row(
          children: [
            Icon(Icons.description_outlined, color: GruvboxColors.aqua, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fileResult.relativePath,
                style: TextStyle(
                  color: GruvboxColors.fg0,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: GruvboxColors.bg2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${fileResult.matchCount}',
                style: TextStyle(color: GruvboxColors.yellow, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        children: fileResult.matchLines.map((line) {
          return InkWell(
            onTap: () {
              Navigator.of(context).pop();
              ref.read(editorProvider.notifier).openFile(fileResult.fileUri, fileResult.fileName);
              ref.read(findReplaceProvider.notifier).openFind(
                    initialQuery: _queryController.text.trim(),
                  );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: GruvboxColors.bg2, width: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Line ${line.lineNumber}:',
                    style: TextStyle(
                      color: GruvboxColors.gray,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line.lineText.trim(),
                      style: TextStyle(
                        color: GruvboxColors.fg,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
