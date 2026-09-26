import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/services/indexer_service.dart';

class RagContextBlock {
  final String fileName;
  final String headingContext;
  final String contentSnippet;
  final String parentFolder;

  const RagContextBlock({
    required this.fileName,
    required this.headingContext,
    required this.contentSnippet,
    required this.parentFolder,
  });
}

class RagService {
  final IndexerService _indexer = IndexerService();

  /// Retrieves relevant context blocks filtered by directory scope and formats them for the LLM system prompt.
  /// Strictly bounded to prevent overflowing the on-device 2048 token context window.
  Future<String> buildPromptContext({
    required String query,
    bool ragEnabled = true,
    String? currentDocUri,
    String? currentDocContent,
    String? parentFolder,
    List<String>? directoryFiles,
    int maxBlocks = 3,
  }) async {
    if (!ragEnabled) return '';
    final buffer = StringBuffer();

    // 1. Document Context (active open document or scoped notes)
    if (currentDocContent != null && currentDocContent.trim().isNotEmpty) {
      final docTitle = currentDocUri != null
          ? p.basename(currentDocUri)
          : (parentFolder != null ? 'Scoped Folder Notes: $parentFolder' : 'Workspace Notes');
      buffer.writeln('=== Active Document Context ($docTitle) ===');
      final safeContent = currentDocContent.length > 3000
          ? '${currentDocContent.substring(0, 3000)}\n...[truncated]'
          : currentDocContent;
      buffer.writeln(safeContent);
      buffer.writeln('==========================================');
      buffer.writeln();
    }

    // 2. Directory structure / files in workspace (exclude models & binary files, up to 150 files)
    if (directoryFiles != null && directoryFiles.isNotEmpty) {
      final filteredFiles = directoryFiles
          .where((f) {
            final lower = f.toLowerCase();
            final isModelDir = lower.contains('models/') || lower.contains('models\\') || lower.startsWith('models');
            final isBinary = lower.endsWith('.gguf') ||
                lower.endsWith('.bin') ||
                lower.endsWith('.task') ||
                lower.endsWith('.apk') ||
                lower.endsWith('.zip') ||
                lower.endsWith('.tar') ||
                lower.endsWith('.db');
            return !isModelDir && !isBinary;
          })
          .take(150)
          .toList();

      if (filteredFiles.isNotEmpty) {
        final isScoped = parentFolder != null &&
            parentFolder.isNotEmpty &&
            parentFolder.toLowerCase() != 'all' &&
            parentFolder.toLowerCase() != 'root';
        final headerTitle = isScoped
            ? 'NOTES IN FOLDER "$parentFolder" (${filteredFiles.length} files)'
            : 'WORKSPACE NOTES LIST Across All Folders (${filteredFiles.length} files)';

        buffer.writeln('=== $headerTitle ===');
        for (final f in filteredFiles) {
          buffer.writeln('- $f');
        }
        buffer.writeln('============================');
        buffer.writeln();
      }
    }

    // 3. Perform search across workspace / directory (capped snippets)
    if (query.trim().isNotEmpty) {
      try {
        final cleanQuery = query.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
        if (cleanQuery.isNotEmpty) {
          final effectiveFolder = (parentFolder != null &&
                  parentFolder.isNotEmpty &&
                  parentFolder.toLowerCase() != 'all' &&
                  parentFolder.toLowerCase() != 'root')
              ? parentFolder
              : null;
          final results = await _indexer.search(cleanQuery, parentFolder: effectiveFolder);

          if (results.isNotEmpty) {
            buffer.writeln('=== RELEVANT NOTES IN WORKSPACE ===');
            final takeCount = results.length < maxBlocks ? results.length : maxBlocks;

            for (int i = 0; i < takeCount; i++) {
              final item = results[i];
              if (currentDocUri != null && item.fileUri == currentDocUri) continue;

              final folderPrefix = (item.parentFolder.isNotEmpty && item.parentFolder != 'root')
                  ? '${item.parentFolder}/'
                  : '';
              buffer.writeln('Note: $folderPrefix${item.fileName} (${item.headingContext}):');
              final safeSnippet = item.snippet.length > 350
                  ? '${item.snippet.substring(0, 350)}...'
                  : item.snippet;
              buffer.writeln(safeSnippet);
              buffer.writeln();
            }
            buffer.writeln('===================================');
          }
        }
      } catch (_) {}
    }

    return buffer.toString().trim();
  }
}
