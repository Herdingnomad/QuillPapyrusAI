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
    String? currentDocUri,
    String? currentDocContent,
    String? parentFolder,
    List<String>? directoryFiles,
    int maxBlocks = 3,
  }) async {
    final buffer = StringBuffer();

    // 1. If active document is open, include current document context (capped at 2500 chars)
    if (currentDocUri != null && currentDocContent != null && currentDocContent.trim().isNotEmpty) {
      final docName = p.basename(currentDocUri);
      buffer.writeln('=== Active Document Context ($docName) ===');
      final safeContent = currentDocContent.length > 2500
          ? '${currentDocContent.substring(0, 2500)}\n...[truncated]'
          : currentDocContent;
      buffer.writeln(safeContent);
      buffer.writeln('==========================================');
      buffer.writeln();
    }

    // 2. Directory structure / files in workspace (exclude models & binary files, max 15 files)
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
          .take(15)
          .toList();

      if (filteredFiles.isNotEmpty) {
        buffer.writeln('=== WORKSPACE NOTES LIST ===');
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
          final results = await _indexer.search(cleanQuery, parentFolder: parentFolder);

          if (results.isNotEmpty) {
            buffer.writeln('=== RELEVANT NOTES IN WORKSPACE ===');
            final takeCount = results.length < maxBlocks ? results.length : maxBlocks;

            for (int i = 0; i < takeCount; i++) {
              final item = results[i];
              if (currentDocUri != null && item.fileUri == currentDocUri) continue;

              buffer.writeln('Note: ${item.fileName} (${item.headingContext}):');
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
